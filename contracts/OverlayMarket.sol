// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./libraries/FixedPoint.sol";
import "./libraries/Position.sol";
import "./interfaces/IOverlayFactory.sol";

import "./OverlayERC1155.sol";
import "./OverlayPricePoint.sol";
import "./OverlayToken.sol";

contract OverlayMarket is OverlayERC1155, OverlayPricePoint {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;
    using Position for Position.Info;
    using SafeERC20 for OverlayToken;

    event Build(address indexed sender, uint256 positionId, uint256 oi, uint256 debt);
    event Unwind(address indexed sender, uint256 positionId, uint256 oi, uint256 debt);
    event Update(address indexed sender, address indexed rewarded, uint256 reward);
    event Liquidate(address indexed sender, address indexed rewarded, uint256 reward);

    // max number of periodSize periods before treat funding as completely rebalanced: done for gas savings on compute funding factor
    uint16 public constant MAX_FUNDING_COMPOUND = 4320; // 30d at 10m for updatePeriod
    uint16 public constant MIN_COLLATERAL_AMOUNT = 10**4;

    // ovl erc20 token
    address public immutable ovl;
    // OverlayFactory address
    address public immutable factory;

    // leverage max allowed for a position: leverages are assumed to be discrete increments of 1
    uint8 public leverageMax;
    // open interest cap on each side long/short
    uint144 public oiCap;
    // period size for calls to update
    uint256 public updatePeriod;

    // open interest funding constant factor, charged per updatePeriod
    // 1/d = 1 - 2k; 0 < k < 1/2, 1 < d < infty
    uint112 public fundingKNumerator;
    uint112 public fundingKDenominator;
    // block at which market update was last called: includes funding payment, fees, price fetching
    uint256 public updateBlockLast;
    // outstanding cumulative fees to be forwarded
    uint256 public fees;

    // total open interest long
    uint256 public oiLong;
    // total open interest short
    uint256 public oiShort;
    // total open interest long shares outstanding
    uint256 private totalOiLongShares;
    // total open interest short shares outstanding
    uint256 private totalOiShortShares;

    // array of pos attributes; id is index in array
    Position.Info[] public positions;

    // mapping from leverage to index in positions array of queued position; queued can still be built on while updatePeriod elapses
    mapping(uint256 => uint256) private queuedPositionLongIds;
    mapping(uint256 => uint256) private queuedPositionShortIds;

    // mapping from position id to price point index pointer
    // @dev used to calculate priceEntry for each position
    mapping(uint256 => uint256) private pricePointIndexes;

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
        require(IOverlayFactory(factory).isMarket(address(this)), "OverlayV1: !enabled");
        _;
    }

    constructor(
        string memory _uri,
        address _ovl,
        uint256 _updatePeriod,
        uint8 _leverageMax,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator
    ) OverlayERC1155(_uri) {
        // immutables
        factory = msg.sender;
        ovl = _ovl;

        // per-market adjustable params
        updatePeriod = _updatePeriod;
        leverageMax = _leverageMax;
        oiCap = _oiCap;

        require(_fundingKDenominator > 2 * _fundingKNumerator, "OverlayV1: invalid k");
        fundingKNumerator = _fundingKNumerator;
        fundingKDenominator = _fundingKDenominator;

        // state params
        updateBlockLast = block.number;
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
        uint256 elapsed = (block.number - updateBlockLast) / updatePeriod;
        return (elapsed > 0);
    }

    /// @notice Transfers funding payments
    /// @dev oiImbalance(m) = oiImbalance(0) * (1 - 2k)**m
    function updateFunding() private returns (uint256 amountToBurn) {
        uint256 elapsed = (block.number - updateBlockLast) / updatePeriod;
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
    }

    /// @notice Computes fee pot distributions and zeroes pot
    function updateFees()
        private
        returns (
            uint256 amountToBurn,
            uint256 amountToForward,
            uint256 amountToRewardUpdates,
            address feeTo
        )
    {
        (
            ,
            uint16 _feeBurnRate,
            uint16 _feeUpdateRewardsRate,
            uint16 _feeResolution,
            address _feeTo,
            ,,,
        ) = IOverlayFactory(factory).getGlobalParams();
        uint256 feeAmount = fees;
        uint256 feeAmountLessBurn = (feeAmount * _feeResolution - feeAmount * _feeBurnRate) / _feeResolution;
        uint256 feeAmountLessBurnAndUpdate = (feeAmountLessBurn * _feeResolution - feeAmountLessBurn * _feeUpdateRewardsRate) / _feeResolution;

        amountToBurn = feeAmount - feeAmountLessBurn;
        amountToForward = feeAmountLessBurnAndUpdate;
        amountToRewardUpdates = feeAmountLessBurn - feeAmountLessBurnAndUpdate;
        feeTo = _feeTo;

        // zero cumulative fees since last update
        fees = 0;
    }

    /// @notice Updates funding payments, cumulative fees, and price points
    function update(address rewardsTo) public {
        uint256 blockNumber = block.number;
        uint256 elapsed = (blockNumber - updateBlockLast) / updatePeriod;
        if (elapsed > 0) {
            (
                uint256 amountToBurn,
                uint256 amountToForward,
                uint256 amountToRewardUpdates,
                address feeTo
            ) = updateFees();
            amountToBurn += updateFunding();
            updatePricePoints();

            updateBlockLast = blockNumber;

            emit Update(msg.sender, rewardsTo, amountToRewardUpdates);

            OverlayToken(ovl).burn(address(this), amountToBurn);
            OverlayToken(ovl).safeTransfer(feeTo, amountToForward);
            OverlayToken(ovl).safeTransfer(rewardsTo, amountToRewardUpdates);
        }
    }

    function updateQueuedPosition(bool isLong, uint256 leverage) private returns (uint256 queuedPositionId) {
        mapping(uint256 => uint256) storage queuedPositionIds = (
            isLong ? queuedPositionLongIds : queuedPositionShortIds
        );
        queuedPositionId = queuedPositionIds[leverage];
        if (pricePointIndexes[queuedPositionId] < pricePointCurrentIndex) {
            // prior update window for this queued position has passed
            positions.push(Position.Info({
                isLong: isLong,
                leverage: leverage,
                oiShares: 0,
                debt: 0,
                cost: 0
            }));
            queuedPositionId = positions.length - 1;
            pricePointIndexes[queuedPositionId] = pricePointCurrentIndex;
            queuedPositionIds[leverage] = queuedPositionId;
        }
    }

    function positionsLength() external view returns (uint256) {
        return positions.length;
    }

    /// @notice Adjusts state variable fee pots, which are transferred on call to update()
    function adjustForFees(uint256 notional) private returns (uint256 notionalAdjusted, uint256 feeAmount) {
        (uint256 fee,,, uint256 feeResolution,,,,,) = IOverlayFactory(factory).getGlobalParams();
        notionalAdjusted = (notional * feeResolution - notional * fee) / feeResolution;
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

        // update market for funding, price points, fees before all else
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
        OverlayToken(ovl).safeTransferFrom(msg.sender, address(this), collateralAmount);
        // mint the debt, before fees, to accomodate funding payment burns (edge case: oiLong == 0 || oiShort == 0)
        OverlayToken(ovl).mint(address(this), oi - collateralAmount);
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
        require(hasPricePoint(pricePointIndexes[positionId]), "OverlayV1: !settled");

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
        uint256 debt = shares * position.debt / totalShares;
        uint256 cost = shares * position.cost / totalShares;

        uint256 valueAdjusted;
        uint256 feeAmount;
        { // avoid stack too deep errors in computing valueAdjusted of position
        uint256 _positionId = positionId;
        uint256 _pricePointCurrentIndex = pricePointCurrentIndex;
        bool _isLong = isLong;
        Position.Info storage _position = position;

        uint256 _shares = shares;
        uint256 _totalShares = totalShares;
        uint256 _totalOi = _isLong ? oiLong : oiShort;
        uint256 _totalOiShares = _isLong ? totalOiLongShares : totalOiShortShares;

        uint256 _debt = debt;
        uint256 _priceEntry = pricePoints[pricePointIndexes[_positionId]];
        uint256 _priceExit = pricePoints[_pricePointCurrentIndex-1]; // potential sacrifice of profit for UX purposes - implicit option to user here since using T instead of T+1 settlement on unwind (T < t < T+1; t=block.number)
        uint256 _notional = _shares * _position.notional(
            _totalOi,
            _totalOiShares,
            _priceEntry,
            _priceExit
        ) / _totalShares;

        // adjust for fees
        // TODO: think through edge case of underwater position ... and fee adjustments ...
        (uint256 _notionalAdjusted, uint256 _feeAmount) = adjustForFees(_notional);
        valueAdjusted = _notionalAdjusted > _debt ? _notionalAdjusted - _debt : 0; // floor in case underwater, and protocol loses out on any maintenance margin
        feeAmount = _feeAmount;
        }

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
            OverlayToken(ovl).mint(address(this), valueAdjusted - cost - debt);
        } else {
            OverlayToken(ovl).burn(address(this), debt + cost - valueAdjusted);
        }

        burn(msg.sender, positionId, shares);
        OverlayToken(ovl).safeTransfer(msg.sender, valueAdjusted);
    }

    /// @notice Adjusts params associated with this market
    function adjustParams(
        uint256 _updatePeriod,
        uint8 _leverageMax,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator
    ) external onlyFactory {
        // TODO: requires on params; particularly leverageMax wrt MAX_FEE and cap
        updatePeriod = _updatePeriod;
        leverageMax = _leverageMax;
        oiCap = _oiCap;

        require(_fundingKDenominator > 2 * _fundingKNumerator, "OverlayV1: invalid k");
        fundingKNumerator = _fundingKNumerator;
        fundingKDenominator = _fundingKDenominator;
    }
}
