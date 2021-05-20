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

    event Build(address indexed sender, uint256 positionId, uint256 oi, uint256 debt);
    event Unwind(address indexed sender, uint256 positionId, uint256 oi, uint256 debt);
    event Update(address indexed sender, address indexed rewarded, uint256 reward);
    event Liquidate(address indexed sender, address indexed rewarded, uint256 reward);

    // max number of periodSize periods before treat funding as completely rebalanced: done for gas savings on compute funding factor
    uint16 public constant MAX_FUNDING_COMPOUND = 4320; // 30d at 10m updatePeriodSize periods
    uint16 public constant MIN_COLLATERAL_AMOUNT = 10**4;

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
    uint8 public leverageMax;
    // period size for sliding window TWAP calc && calls to update
    uint256 public updatePeriodSize;
    // window size for sliding window TWAP calc
    uint256 public windowSize;
    // open interest cap on each side long/short
    uint144 public oiCap;

    // open interest funding constant factor, charged per updatePeriodSize
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
    // mapping from leverage to index in positions array of queued position; queued can still be built on while updatePeriodSize elapses
    mapping(uint8 => uint256) private queuedPositionLongIds;
    mapping(uint8 => uint256) private queuedPositionShortIds;


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
        uint256 _updatePeriodSize,
        uint256 _windowSize,
        uint8 _leverageMax,
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
        updatePeriodSize = _updatePeriodSize;
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

    // SEE: https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/examples/ExampleSlidingWindowOracle.sol#L93
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
        uint256 elapsed = (block.number - updateBlockLast) / updatePeriodSize;
        return (elapsed > 0);
    }

    /// @notice Updates funding payments, price point index pointer, and cumulative fees
    function update(address rewardsTo) public {
        // TODO: add in updates to price point index pointer
        uint256 blockNumber = block.number;
        uint256 elapsed = (blockNumber - updateBlockLast) / updatePeriodSize;
        if (elapsed > 0) {
            // For OVL transfers after calc funding and fees
            uint256 amountToBurn;
            uint256 amountToForward;
            uint256 amountToRewardUpdates;

            // Transfer funding payments
            // oiImbNow = oiImb * (1 - 2k)**m
            FixedPoint.uq144x112 memory fundingFactor = computeFundingFactor(
                fundingKDenominator - 2 * fundingKNumerator,
                fundingKDenominator,
                elapsed
            );
            if (oiShort == 0) {
                uint256 oiLongNow = fundingFactor.mul(oiLong).decode144();
                amountToBurn = oiLong - oiLongNow;
                oiLong = oiLongNow;
            } else if (oiLong == 0) {
                uint256 oiShortNow = fundingFactor.mul(oiShort).decode144();
                amountToBurn = oiShort - oiShortNow;
                oiShort = oiShortNow;
            } else if (oiLong > oiShort) {
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

            amountToForward = feeAmountLessBurnAndUpdate;
            amountToRewardUpdates = feeAmountLessBurn - feeAmountLessBurnAndUpdate;
            amountToBurn += feeAmount - feeAmountLessBurn;

            fees = 0;
            updateBlockLast = blockNumber;

            emit Update(msg.sender, rewardsTo, amountToRewardUpdates);

            OVLToken(ovl).burn(address(this), amountToBurn);
            OVLToken(ovl).safeTransfer(feeTo, amountToForward);
            OVLToken(ovl).safeTransfer(rewardsTo, amountToRewardUpdates);
        }
    }

    function updateQueuedPosition(bool isLong, uint256 leverage) private returns (uint256 queuedPositionId) {
        // TODO: implement this PROPERLY so users pool collateral within updatePeriodSize windows
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
    function adjustForFees(uint256 notional) private returns (uint256 notionalAdjusted, uint256 feeAmount) {
        (uint256 fee,,, uint256 FEE_RESOLUTION,,,,,) = IOVLFactory(factory).getGlobalParams();
        notionalAdjusted = (notional * FEE_RESOLUTION - notional * fee) / FEE_RESOLUTION;
        feeAmount = notional - notionalAdjusted;
    }

    /// @notice Builds a new position
    function build(
        uint256 collateralAmount,
        bool isLong,
        uint256 leverage,
        address rewardsTo
    ) external lock enabled {
        require(collateralAmount >= MIN_COLLATERAL_AMOUNT, "OverlayV1: invalid collateral amount");
        require(leverage >= 1 && leverage <= leverageMax, "OverlayV1: invalid leverage");

        // update market for funding, price point, fees before all else
        update(rewardsTo);

        uint256 positionId = updateQueuedPosition(isLong, leverage);
        Position.Info storage position = positions[positionId];
        uint256 oi = collateralAmount * leverage;

        // adjust for fees
        (uint256 oiAdjusted, uint256 feeAmount) = adjustForFees(oi);
        uint256 collateralAmountAdjusted = oiAdjusted / leverage;
        uint256 debtAdjusted = oiAdjusted - collateralAmountAdjusted;

        // effects
        fees += feeAmount; // adds to fee pot, which is transferred on update
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
        emit Build(msg.sender, positionId, oiAdjusted, debtAdjusted);

        // interactions
        OVLToken(ovl).safeTransferFrom(msg.sender, address(this), collateralAmount);
        // mint the debt, before fees, to accomodate funding payment burns (edge case: oiLong == 0 || oiShort == 0)
        OVLToken(ovl).mint(address(this), oi - collateralAmount);
        // WARNING: _mint shares should be last given erc1155 callback; mint shares based on OI contribution
        mint(msg.sender, positionId, oiAdjusted, "");
    }

    /// @notice Unwinds shares of an existing position
    function unwind(
        uint256 positionId,
        uint256 shares,
        address rewardsTo
    ) external lock enabled {
        require(positionId < positions.length, "OverlayV1: invalid position id");
        require(shares > 0 && shares <= balanceOf(msg.sender, positionId), "OverlayV1: invalid position shares");

        // update market for funding, price point, fees before all else
        update(rewardsTo);

        Position.Info storage position = positions[positionId];
        bool isLong = position.isLong;
        uint256 totalShares = totalPositionShares[positionId];
        uint256 posOiShares = shares * position.oiShares / totalShares;

        uint256 oi = shares * position.openInterest(
            isLong ? oiLong : oiShort, // totalOi
            isLong ? totalOiLongShares : totalOiShortShares // totalOiShares
        ) / totalShares;
        uint256 notional = shares * position.notional(
            isLong ? oiLong : oiShort, // totalOi
            isLong ? totalOiLongShares : totalOiShortShares, // totalOiShares
            0, // priceEntry: TODO: compute entry price
            lastPrice() // priceExit: potential sacrifice of profit from protocol for UX purposes
        ) / totalShares;
        uint256 debt = shares * position.debt / totalShares;
        uint256 cost = shares * position.cost / totalShares;

        // adjust for fees
        // TODO: think through edge case of underwater position ... and fee adjustments ...
        (uint256 notionalAdjusted, uint256 feeAmount) = adjustForFees(notional);
        uint256 valueAdjusted = notionalAdjusted > debt ? notionalAdjusted - debt : 0; // floor in case underwater, and protocol loses out on any maintenance margin

        // effects
        fees += feeAmount; // adds to fee pot, which is transferred on update
        position.oiShares -= posOiShares;
        position.debt -= debt;
        position.cost -= cost;
        if (isLong) {
            oiLong -= oi;
            totalOiLongShares -= posOiShares;
        } else {
            oiShort -= oi;
            totalOiShortShares -= posOiShares;
        }

        // events
        emit Unwind(msg.sender, positionId, oi, debt);

        // interactions
        // mint/burn excess PnL = valueAdjusted - cost, accounting for need to also burn debt
        if (debt + cost < valueAdjusted) {
            OVLToken(ovl).mint(address(this), valueAdjusted - cost - debt);
        } else {
            OVLToken(ovl).burn(address(this), debt + cost - valueAdjusted);
        }

        burn(msg.sender, positionId, shares);
        OVLToken(ovl).safeTransfer(msg.sender, valueAdjusted);
    }

    /// @notice Adjusts params associated with this market
    function adjustParams(
        uint256 _updatePeriodSize,
        uint256 _windowSize,
        uint8 _leverageMax,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator
    ) external onlyFactory {
        // TODO: requires on params; particularly leverageMax wrt MAX_FEE and cap
        updatePeriodSize = _updatePeriodSize;
        windowSize = _windowSize;
        leverageMax = _leverageMax;
        oiCap = _oiCap;

        require(_fundingKDenominator > 2 * _fundingKNumerator, "OverlayV1: invalid k");
        fundingKNumerator = _fundingKNumerator;
        fundingKDenominator = _fundingKDenominator;
    }
}
