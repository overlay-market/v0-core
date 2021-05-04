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

    // ovl erc20 token
    address public immutable ovl;
    // OVLMirinFactory address
    address public immutable factory;
    // mirin pool and factory addresses
    address public immutable mirinFactory;
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
    uint256 public cap;
    // open interest funding constant, charged per block
    uint256 public k;

    // total open interest long
    uint256 public oiLong;
    // total open interest short
    uint256 public oiShort;
    // total open interest long shares outstanding
    uint256 public totalOiLongShares;
    // total open interest short shares outstanding
    uint256 public totalOiShortShares;

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
        require(unlocked == 1, "!unlocked");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "!factory");
        _;
    }

    modifier enabled() {
        require(IOVLFactory(factory).isMarket(address(this)), "!enabled");
        _;
    }

    constructor(
        address _ovl,
        address _mirinFactory,
        address _mirinPool,
        bool _isPrice0,
        uint256 _periodSize,
        uint256 _windowSize,
        uint256 _leverageMax,
        uint256 _cap,
        uint256 _k
    ) {
        // immutables
        factory = msg.sender;
        ovl = _ovl;
        mirinFactory = _mirinFactory;
        mirinPool = _mirinPool;
        isPrice0 = _isPrice0;

        // per-market adjustable params
        periodSize = _periodSize;
        windowSize = _windowSize;
        leverageMax = _leverageMax;
        cap = _cap;
        k = _k;
    }

    // mint overrides erc1155 _mint to track total shares issued for given position id
    function mint(address account, uint256 id, uint256 shares, bytes memory data) private {
        totalPositionShares[id] += shares;
        _mint(account, id, shares, data);
    }

    // burn overrides erc1155 _burn to track total shares issued for given position id
    function burn(address account, uint256 id, uint256 shares) private {
        uint256 totalShares = totalPositionShares[id];
        require(totalShares >= shares, "burn shares exceeds total");
        totalPositionShares[id] = totalShares - shares;
        _burn(account, id, shares);
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
        require(len > windowSize, "!mirin initialized");
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

    function adjustForFees(uint256 value, uint256 valueWithoutDebt) private returns (
        uint256 valueAdjusted,
        uint256 feeAmountToForward,
        uint256 feeAmountToBurn,
        address feeTo
    ) {
        (uint16 fee, uint16 feeBurnRate, uint16 FEE_RESOLUTION, address _feeTo,,,,) = IOVLFactory(factory).getGlobal();
        // collateral less fees
        valueAdjusted = (value * FEE_RESOLUTION - valueWithoutDebt * fee) / FEE_RESOLUTION;

        // fee amounts
        uint256 feeAmount = value - valueAdjusted;
        feeAmountToForward = (feeAmount * FEE_RESOLUTION - feeAmount * feeBurnRate) / FEE_RESOLUTION;
        feeAmountToBurn = feeAmount - feeAmountToForward;

        feeTo = _feeTo;
    }

    function build(
        uint256 collateralAmount,
        bool isLong,
        uint256 leverage
    ) external lock enabled {
        require(leverage >= 1 && leverage <= leverageMax, "invalid leverage");
        // TODO: updateFunding();
        uint256 positionId = updateQueuedPosition(isLong, leverage);
        Position.Info storage position = positions[positionId];

        // compute fees
        (
            uint256 collateralAmountAdjusted,
            uint256 feeAmountToForward,
            uint256 feeAmountToBurn,
            address feeTo
        ) = adjustForFees(collateralAmount, collateralAmount * leverage);

        // effects
        // position
        position.oiShares += collateralAmountAdjusted * leverage;
        position.debt += (leverage - 1) * collateralAmountAdjusted;
        position.cost += collateralAmountAdjusted;

        // totals
        if (isLong) {
            oiLong += collateralAmountAdjusted * leverage;
            require(oiLong <= cap, "invalid oi = collateral*leverage; breached cap");
            totalOiLongShares += collateralAmountAdjusted * leverage;
        } else {
            oiShort += collateralAmountAdjusted * leverage;
            require(oiShort <= cap, "invalid oi = collateral*leverage; breached cap");
            totalOiShortShares += collateralAmountAdjusted * leverage;
        }

        // interactions
        // transfer collateral + fees into pool then mint shares of queued position
        OVLToken(ovl).safeTransferFrom(msg.sender, address(this), collateralAmount);
        // Forward and burn fees
        OVLToken(ovl).safeTransfer(feeTo, feeAmountToForward);
        OVLToken(ovl).burn(address(this), feeAmountToBurn);
        // WARNING: _mint erc1155 shares last given callback
        // mint shares based on oi contribution
        mint(msg.sender, positionId, collateralAmountAdjusted * leverage, "");
    }

    function unwind(uint256 positionId, uint256 shares) external lock enabled {
        require(positionId < positions.length, "invalid position id");
        require(shares <= balanceOf(msg.sender, positionId), "invalid shares");
        // TODO: updateFunding();
        Position.Info storage position = positions[positionId];
        uint256 priceEntry = 0; // TODO: compute entry price
        uint256 priceExit = lastPrice(); // potential sacrifice of profit for UX purposes; SEE: "Queueing Position Builds" https://oips.overlay.market/notes/note-2

        // calculate value, cost
        uint256 value = shares * position.value(
            (position.isLong ? oiLong : oiShort),
            (position.isLong ? totalOiLongShares : totalOiShortShares),
            priceEntry,
            priceExit
        ) / totalPositionShares[positionId];
        uint256 valueWithoutDebt = value + shares * position.debt / totalPositionShares[positionId];
        uint256 cost = shares * position.cost / totalPositionShares[positionId];

        // effects
        // position
        uint256 oiDiff = (
            position.isLong ?
            (shares * position.oiShares * oiLong / totalOiLongShares) / totalPositionShares[positionId] :
            (shares * position.oiShares * oiShort / totalOiShortShares) / totalPositionShares[positionId]
        );
        position.oiShares -= oiDiff;
        position.debt -= shares * position.debt / totalPositionShares[positionId];
        position.cost -= shares * position.cost / totalPositionShares[positionId];

        // totals
        if (position.isLong) {
            oiLong -= oiDiff;
            totalOiLongShares -= oiDiff;
        } else {
            oiShort -= oiDiff;
            totalOiShortShares -= oiDiff;
        }

        // compute fees
        // NOTE: Not using valueAdjusted in effects given withdrawing funds from contract
        // so only need to adjust PnL calcs and amount sent back to msg.sender
        (
            uint256 valueAdjusted,
            uint256 feeAmountToForward,
            uint256 feeAmountToBurn,
            address feeTo
        ) = adjustForFees(value, valueWithoutDebt);

        // interactions
        if (valueAdjusted >= cost) {
            // profit: mint the diff
            uint256 diff = valueAdjusted - cost;
            OVLToken(ovl).mint(address(this), diff);
        } else {
            // loss: burn the diff
            // NOTE: can at most burn cost given value min is restricted to zero
            // TODO: Floor in case rounding errors with cost for total collateral in contract?
            uint256 diff = cost - valueAdjusted;
            OVLToken(ovl).burn(address(this), diff);
        }

        // burn shares of position then transfer collateral + PnL
        burn(msg.sender, positionId, shares);
        // Forward and burn fees
        OVLToken(ovl).safeTransfer(feeTo, feeAmountToForward);
        OVLToken(ovl).burn(address(this), feeAmountToBurn);
        // transfer collateral + PnL
        OVLToken(ovl).safeTransfer(msg.sender, valueAdjusted);
    }

    // adjusts params associated with this market
    function adjust(
        uint256 _periodSize,
        uint256 _windowSize,
        uint256 _leverageMax,
        uint256 _cap,
        uint256 _k
    ) external onlyFactory {
        // TODO: requires on params; particularly leverageMax wrt MAX_FEE
        periodSize = _periodSize;
        windowSize = _windowSize;
        leverageMax = _leverageMax;
        cap = _cap;
        k = _k;
    }
}
