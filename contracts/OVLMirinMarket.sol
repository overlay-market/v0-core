// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./libraries/FixedPoint.sol";
import "./libraries/Position.sol";

import "./interfaces/IMirinOracle.sol";
import "./interfaces/IOVLFactory.sol";

import "./OVLToken.sol";

contract OVLMirinMarket is ERC1155("https://metadata.overlay.exchange/mirin/{id}.json") {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;
    using Position for Position.Info;
    using SafeERC20 for OVLToken;

    event Build(address indexed sender, uint256 positionId, bool isLong, uint256 oi, uint256 debt);
    event Unwind(address indexed sender, uint256 positionId, uint256 oi, uint256 debt);
    event Update(address indexed sender, address indexed rewarded, uint256 reward);

    // max number of periodSize periods before treat funding as completely rebalanced: done for gas savings on compute funding factor
    uint16 public constant MAX_FUNDING_COMPOUND = 4320; // 30d at 10m periodSize periods

    // ovl erc20 token
    address public immutable ovl;
    // OVLMirinFactory address
    address public immutable factory;
    // mirin pool address
    address public immutable mirinPool;
    bool public immutable isPrice0;

    struct PricePointWindow {
        uint256 pricePointStartIndex; // index in mirin oracle's pricePoints to use as start of TWAP calculation for position entry (lock) price
        uint256 pricePointEndIndex; // index in mirin oracle's pricePoints to use as end of TWAP calculation for position entry (lock) price
    }

    // leverage max allowed for a position: leverages are assumed to be discrete increments of 1
    uint256 public leverageMax;
    // period size for sliding window TWAP calc
    uint256 public periodSize;
    // window size for sliding window TWAP calc
    uint256 public windowSize;
    // open interest cap on each side long/short
    uint144 public oiCap;

    // open interest funding constant factor, charged per periodSize
    // 1/d = 1 - 2k; 0 < k < 1/2, 1 < d < infty
    uint112 public fundingKNumerator;
    uint112 public fundingKDenominator;
    // block at which market update was last called: includes funding payment, fees, price fetching
    uint256 public updateBlockLast;

    // total open interest long
    uint256 public oiLong;
    // total open interest short
    uint256 public oiShort;
    // total open interest long shares outstanding
    uint256 private totalOiLongShares;
    // total open interest short shares outstanding
    uint256 private totalOiShortShares;

    // outstanding cumulative fees to be forwarded
    uint256 public fees;

    // array of pos attributes; id is index in array
    Position.Info[] public positions;
    // mapping from position id to total shares
    mapping(uint256 => uint256) public totalPositionShares;
    // mapping from position id to price point window
    mapping(uint256 => PricePointWindow) private pricePointWindows;
    // mapping from leverage to index in positions array of queued position; queued can still be built on while periodSize elapses
    mapping(uint256 => uint256) private queuedPositionLongIds;
    mapping(uint256 => uint256) private queuedPositionShortIds;


    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "OverlayV1: !unlocked");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "OverlayV1: !factory");
        _;
    }

    modifier enabled() {
        require(IOVLFactory(factory).isMarket(address(this)), "OverlayV1: !enabled");
        _;
    }

    constructor(
        address _ovl,
        address _mirinPool,
        bool _isPrice0,
        uint256 _periodSize,
        uint256 _windowSize,
        uint256 _leverageMax,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator
    ) {
        // immutables
        factory = msg.sender;
        ovl = _ovl;
        mirinPool = _mirinPool;
        isPrice0 = _isPrice0;

        // per-market adjustable params
        periodSize = _periodSize;
        windowSize = _windowSize;
        leverageMax = _leverageMax;
        oiCap = _oiCap;

        require(_fundingKDenominator > 2 * _fundingKNumerator, "OverlayV1: invalid k");
        fundingKNumerator = _fundingKNumerator;
        fundingKDenominator = _fundingKDenominator;

        // state params
        updateBlockLast = block.number;
    }

    // mint overrides erc1155 _mint to track total shares issued for given position id
    function mint(address account, uint256 id, uint256 shares, bytes memory data) private {
        totalPositionShares[id] += shares;
        _mint(account, id, shares, data);
    }

    // burn overrides erc1155 _burn to track total shares issued for given position id
    function burn(address account, uint256 id, uint256 shares) private {
        uint256 totalShares = totalPositionShares[id];
        require(totalShares >= shares, "OverlayV1: burn shares exceeds total");
        totalPositionShares[id] = totalShares - shares;
        _burn(account, id, shares);
    }

    function setURI(string memory newuri) external onlyFactory {
        _setURI(newuri);
    }

    // SEE: https://github.com/sushiswap/mirin/blob/master/contracts/pool/MirinOracle.sol#L112
    function computeAmountOut(
        uint256 priceCumulativeStart,
        uint256 priceCumulativeEnd,
        uint256 timeElapsed,
        uint256 amountIn
    ) private pure returns (uint256 amountOut) {
        // overflow is desired.
        FixedPoint.uq112x112 memory priceAverage =
            FixedPoint.uq112x112(uint224((priceCumulativeEnd - priceCumulativeStart) / timeElapsed));
        amountOut = priceAverage.mul(amountIn).decode144();
    }

    function lastPrice() public view returns (uint256) {
        uint256 len = IMirinOracle(mirinPool).pricePointsLength();
        require(len > windowSize, "OverlayV1: !MirinInitialized");
        (
            uint256 timestampEnd,
            uint256 price0CumulativeEnd,
            uint256 price1CumulativeEnd
        ) = IMirinOracle(mirinPool).pricePoints(len-1);
        (
            uint256 timestampStart,
            uint256 price0CumulativeStart,
            uint256 price1CumulativeStart
        ) = IMirinOracle(mirinPool).pricePoints(len-1-windowSize);

        if (isPrice0) {
            return computeAmountOut(
                price0CumulativeStart,
                price0CumulativeEnd,
                timestampEnd - timestampStart,
                0 // TODO: Fix w decimals
            );
        } else {
            return computeAmountOut(
                price1CumulativeStart,
                price1CumulativeEnd,
                timestampEnd - timestampStart,
                0 // TODO: Fix w decimals
            );
        }
    }

    /// @notice Computes f**m
    /// @dev Works properly only when _fNumerator < _fDenominator
    function computeFundingFactor(
        uint112 _fNumerator,
        uint112 _fDenominator,
        uint256 _m
    ) private pure returns (FixedPoint.uq144x112 memory factor) {
        // TODO: do we want to store values up to power MAX_FUNDING_COMPOUND as an array on adjustParam() call? so trader isn't paying gas to compute
        if (_m > MAX_FUNDING_COMPOUND) {
            // cut off the recursion if power too large
            factor = FixedPoint.encode144(0);
        } else {
            FixedPoint.uq144x112 memory f = FixedPoint.fraction144(_fNumerator, _fDenominator);
            factor = FixedPoint.pow(f, _m);
        }
    }

    /// @notice Whether the market can be successfully updated
    function updatable() external view returns (bool) {
        uint256 elapsed = (block.number - updateBlockLast) / periodSize;
        return (elapsed > 0);
    }

    /// @notice Updates funding payments, price point index pointer, and cumulative fees
    function update(address rewardsTo) public {
        // TODO: add in updates to price point index pointer
        uint256 blockNumber = block.number;
        uint256 elapsed = (blockNumber - updateBlockLast) / periodSize;
        if (elapsed > 0) {
            // Transfer funding payments
            // oiImbNow = oiImb * (1 - 2k)**m
            FixedPoint.uq144x112 memory fundingFactor = computeFundingFactor(
                fundingKDenominator - 2 * fundingKNumerator,
                fundingKDenominator,
                elapsed
            );
            // TODO: decide how to handle edge cases of oiLong == 0 || oiShort == 0
            // TODO: likely switch to minting debt to cover all of OI locked in contract on build
            // and burning debt on unwind
            if (oiLong > oiShort) {
                uint256 oiImbNow = fundingFactor.mul(oiLong - oiShort).decode144();
                oiLong = (oiLong + oiShort + oiImbNow) / 2;
                oiShort = (oiLong + oiShort - oiImbNow) / 2;
            } else {
                uint256 oiImbNow = fundingFactor.mul(oiShort - oiLong).decode144();
                oiShort = (oiLong + oiShort + oiImbNow) / 2;
                oiLong = (oiLong + oiShort - oiImbNow) / 2;
            }

            // Forward and burn fees
            (
                ,
                uint16 feeBurnRate,
                uint16 feeUpdateRewardsRate,
                uint16 FEE_RESOLUTION,
                address feeTo,
                ,,,
            ) = IOVLFactory(factory).getGlobalParams();

            // fee amounts with some accounting
            uint256 feeAmount = fees;
            uint256 feeAmountLessBurn = (feeAmount * FEE_RESOLUTION - feeAmount * feeBurnRate) / FEE_RESOLUTION;
            uint256 feeAmountLessBurnAndUpdate = (feeAmountLessBurn * FEE_RESOLUTION - feeAmountLessBurn * feeUpdateRewardsRate) / FEE_RESOLUTION;

            uint256 feeAmountToForward = feeAmountLessBurnAndUpdate;
            uint256 feeAmountToBurn = feeAmount - feeAmountLessBurn;
            uint256 feeAmountToRewardUpdates = feeAmountLessBurn - feeAmountLessBurnAndUpdate;

            fees = 0;
            updateBlockLast = blockNumber;

            emit Update(msg.sender, rewardsTo, feeAmountToRewardUpdates);

            OVLToken(ovl).burn(address(this), feeAmountToBurn);
            OVLToken(ovl).safeTransfer(feeTo, feeAmountToForward);
            OVLToken(ovl).safeTransfer(rewardsTo, feeAmountToRewardUpdates);
        }
    }

    function updateQueuedPosition(bool isLong, uint256 leverage) private returns (uint256 queuedPositionId) {
        // TODO: implement this PROPERLY so users pool collateral within periodSize windows
        positions.push(Position.Info({
            isLong: isLong,
            leverage: leverage,
            oiShares: 0,
            debt: 0,
            cost: 0
        }));
        queuedPositionId = positions.length - 1;
        pricePointWindows[queuedPositionId] = PricePointWindow({
            pricePointStartIndex: 0,
            pricePointEndIndex: 0
        });
    }

    function positionsLength() external view returns (uint256) {
        return positions.length;
    }

    /// @notice Adjusts state variable fee pots, which are transferred on call to update()
    function adjustForFees(uint256 value, uint256 notional) private returns (uint256 valueAdjusted) {
        (uint256 fee,,, uint256 FEE_RESOLUTION,,,,,) = IOVLFactory(factory).getGlobalParams();
        // TODO: check valueAdjusted doesn't go negative ... floor at zero
        valueAdjusted = (value * FEE_RESOLUTION - notional * fee) / FEE_RESOLUTION;
        fees += value - valueAdjusted;
    }

    function build(
        uint256 collateralAmount,
        bool isLong,
        uint256 leverage,
        address rewardsTo
    ) external lock enabled {
        require(collateralAmount > 0, "OverlayV1: invalid amount");
        require(leverage >= 1 && leverage <= leverageMax, "OverlayV1: invalid leverage");

        update(rewardsTo);
        uint256 positionId = updateQueuedPosition(isLong, leverage);
        Position.Info storage position = positions[positionId];

        // adjust for fees
        uint256 collateralAmountAdjusted = adjustForFees(collateralAmount, collateralAmount * leverage);
        uint256 oiAdjusted = collateralAmountAdjusted * leverage;
        uint256 debtAdjusted = (leverage - 1) * collateralAmountAdjusted;

        // effects
        position.oiShares += oiAdjusted;
        position.debt += debtAdjusted;
        position.cost += collateralAmountAdjusted;
        if (isLong) {
            oiLong += oiAdjusted;
            require(oiLong <= oiCap, "OverlayV1: breached oi cap");
            totalOiLongShares += oiAdjusted;
        } else {
            oiShort += oiAdjusted;
            require(oiShort <= oiCap, "OverlayV1: breached oi cap");
            totalOiShortShares += oiAdjusted;
        }

        // events
        emit Build(msg.sender, positionId, isLong, oiAdjusted, debtAdjusted);

        // interactions
        OVLToken(ovl).safeTransferFrom(msg.sender, address(this), collateralAmount);
        // WARNING: _mint erc1155 shares last given callback; mint shares based on OI contribution
        mint(msg.sender, positionId, collateralAmountAdjusted * leverage, "");
    }

    function unwind(
        uint256 positionId,
        uint256 shares,
        address rewardsTo
    ) external lock enabled {
        require(positionId < positions.length, "OverlayV1: invalid position id");
        require(shares > 0 && shares <= balanceOf(msg.sender, positionId), "OverlayV1: invalid shares");

        update(rewardsTo);
        Position.Info storage position = positions[positionId];
        uint256 priceEntry = 0; // TODO: compute entry price
        uint256 priceExit = lastPrice(); // potential sacrifice of profit for UX purposes
        uint256 totalShares = totalPositionShares[positionId];

        uint256 value = shares * position.value(
            (position.isLong ? oiLong : oiShort),
            (position.isLong ? totalOiLongShares : totalOiShortShares),
            priceEntry,
            priceExit
        ) / totalShares;
        uint256 debt = shares * position.debt / totalShares;
        uint256 cost = shares * position.cost / totalShares;

        // adjust for fees ... NOTE: Not using valueAdjusted in effects, given withdrawing funds from contract
        uint256 valueAdjusted = adjustForFees(
            value,
            value + shares * position.debt / totalShares // notional
        );

        // effects
        uint256 oi = (
            position.isLong ?
            (shares * position.oiShares * oiLong / totalOiLongShares) / totalShares :
            (shares * position.oiShares * oiShort / totalOiShortShares) / totalShares
        );
        position.oiShares -= oi;
        position.debt -= debt;
        position.cost -= cost;
        if (position.isLong) {
            oiLong -= oi;
            totalOiLongShares -= oi;
        } else {
            oiShort -= oi;
            totalOiShortShares -= oi;
        }

        // events
        emit Unwind(msg.sender, positionId, oi, debt);

        // interactions
        if (valueAdjusted >= cost) {
            // profit: mint the diff
            uint256 diff = valueAdjusted - cost;
            OVLToken(ovl).mint(address(this), diff);
        } else {
            // loss: burn the diff ... NOTE: can at most burn cost given value min is restricted to zero; TODO: Floor in case rounding errors with cost for total collateral in contract?
            uint256 diff = cost - valueAdjusted;
            OVLToken(ovl).burn(address(this), diff);
        }

        burn(msg.sender, positionId, shares);
        OVLToken(ovl).safeTransfer(msg.sender, valueAdjusted);
    }

    /// @notice Adjusts params associated with this market
    function adjustParams(
        uint256 _periodSize,
        uint256 _windowSize,
        uint256 _leverageMax,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator
    ) external onlyFactory {
        // TODO: requires on params; particularly leverageMax wrt MAX_FEE and cap
        periodSize = _periodSize;
        windowSize = _windowSize;
        leverageMax = _leverageMax;
        oiCap = _oiCap;

        require(_fundingKDenominator > 2 * _fundingKNumerator, "OverlayV1: invalid k");
        fundingKNumerator = _fundingKNumerator;
        fundingKDenominator = _fundingKDenominator;
    }
}
