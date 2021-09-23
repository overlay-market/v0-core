
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../libraries/Position.sol";
import "../libraries/FixedPoint.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "../interfaces/IOverlayV1Market.sol";
import "../interfaces/IOverlayV1Mothership.sol";
import "../interfaces/IOverlayToken.sol";

contract OverlayV1OVLCollateral is ERC1155Supply {

    using Position for Position.Info;
    using FixedPoint for uint256;

    uint256 constant public MIN_COLLAT = 1e14;
    bytes32 constant private GOVERNOR = keccak256("GOVERNOR");

    mapping (address => mapping(uint => uint)) internal queuedPositionLongs;
    mapping (address => mapping(uint => uint)) internal queuedPositionShorts;
    mapping (address => MarketInfo) marketInfo;
    struct MarketInfo { 
        uint marginMaintenance;
        uint marginRewardRate;
    }

    Position.Info[] public positions;

    IOverlayV1Mothership public immutable mothership;
    IOverlayToken public ovl;

    uint256 public fees;
    uint256 public liquidations;

    event Build(uint256 positionId, uint256 oi, uint256 debt);
    event Unwind(uint256 positionId, uint256 oi, uint256 debt);
    event Liquidate(uint256 positionId, address rewarded, uint256 reward);
    event Update(
        address rewarded, 
        uint rewardAmount, 
        uint feesCollected, 
        uint feesBurned, 
        uint liquidationsCollected, 
        uint liquidationsBurned 
    );

    modifier onlyGovernor () {
        require(mothership.hasRole(GOVERNOR, msg.sender), "OVLV1:!governor");
        _;
    }

    constructor (
        string memory _uri,
        address _mothership
    ) ERC1155(_uri) { 

        mothership = IOverlayV1Mothership(_mothership);

        ovl = IOverlayV1Mothership(_mothership).ovl();

        positions.push(Position.Info({
            market: address(0),
            isLong: false,
            leverage: 0,
            pricePoint: 0,
            oiShares: 0,
            debt: 0,
            cost: 0,
            compounding: 0
        }));

    }

    function setMarketInfo (
        address _market,
        uint _marginMaintenance,
        uint _marginRewardRate
    ) external onlyGovernor {

        marketInfo[_market].marginMaintenance = _marginMaintenance;
        marketInfo[_market].marginRewardRate = _marginRewardRate;

    }


    /// @notice Updates funding payments, cumulative fees, queued position builds, and price points
    function update(
        address _market,
        address _rewardsTo
    ) public {


        (   uint256 _marginBurnRate,
            uint256 _feeBurnRate,
            uint256 _feeRewardsRate,
            address _feeTo ) = mothership.getUpdateParams();

        uint _feeForward = fees;
        uint _feeBurn = _feeForward.mulUp(_feeBurnRate);
        uint _feeReward = _feeForward.mulUp(_feeRewardsRate);
        _feeForward = _feeForward - _feeBurn - _feeReward;

        uint _liqForward = liquidations;
        uint _liqBurn = _liqForward.mulUp(_marginBurnRate);
        _liqForward -= _liqBurn;

        fees = 0;
        liquidations = 0;

        emit Update(
            _rewardsTo,
            _feeReward,
            _feeForward,
            _feeBurn,
            _liqForward,
            _liqBurn
        );

        ovl.burn(address(this), _feeBurn + _liqBurn);
        ovl.transfer(_feeTo, _feeForward + _liqForward);
        ovl.transfer(_rewardsTo, _feeReward);

    }

    function getQueuedPositionId (
        address _market,
        bool _isLong,
        uint _leverage,
        uint _pricePointCurrent,
        uint _t1Compounding
    ) internal returns (uint positionId_) {

        mapping(uint=>uint) storage _queuedPositions = _isLong 
            ? queuedPositionLongs[_market]
            : queuedPositionShorts[_market];

        positionId_ = _queuedPositions[_leverage];

        Position.Info storage position = positions[positionId_];

        if (position.pricePoint < _pricePointCurrent) {

            positions.push(Position.Info({
                market: _market,
                isLong: _isLong,
                leverage: _leverage,
                pricePoint: _pricePointCurrent,
                oiShares: 0,
                debt: 0,
                cost: 0,
                compounding: _t1Compounding
            }));

            positionId_ = positions.length - 1;

            _queuedPositions[_leverage] = positionId_;

        }

    }

    function build(
        address _market,
        uint256 _collateral,
        uint256 _leverage,
        bool _isLong
    ) external {

        require(MIN_COLLAT <= _collateral, "OVLV1:collat<min");

        (   uint _oiAdjusted,
            uint _collateralAdjusted,
            uint _debtAdjusted,
            uint _fee,
            uint _impact,
            uint _pricePointCurrent,
            uint _t1Compounding ) = IOverlayV1Market(_market)
                .enterOI(
                    _isLong, 
                    _collateral, 
                    _leverage
                );

        uint _positionId = getQueuedPositionId(
            _market, 
            _isLong, 
            _leverage, 
            _pricePointCurrent,
            _t1Compounding
        );

        Position.Info storage pos = positions[_positionId];

        pos.oiShares += _oiAdjusted;
        pos.cost += _collateralAdjusted;
        pos.debt += _debtAdjusted;

        fees += _fee;

        emit Build(_positionId, _oiAdjusted, _debtAdjusted);

        ovl.transferFrom(msg.sender, address(this), _collateral);

        ovl.burn(address(this), _impact);

        _mint(msg.sender, _positionId, _oiAdjusted, ""); // WARNING: last b/c erc1155 callback

    }

    /// @notice Unwinds shares of an existing position
    function unwind(
        uint256 _positionId,
        uint256 _shares
    ) external {

        require( 0 < _shares && _shares <= balanceOf(msg.sender, _positionId), "OVLV1:!shares");

        Position.Info storage pos = positions[_positionId];

        require(0 < pos.oiShares, "OVLV1:liquidated");

        {

        (   uint _oi,
            uint _oiShares,
            uint _priceFrame,
            uint _tCompounding ) = IOverlayV1Market(pos.market).exitData(pos.isLong, pos.pricePoint);
        
        uint _totalPosShares = totalSupply(_positionId);

        uint _userOiShares = _shares * pos.oiShares / _totalPosShares;
        uint _userNotional = _shares * pos.notional(_priceFrame, _oi, _oiShares) / _totalPosShares;
        uint _userDebt = _shares * pos.debt / _totalPosShares;
        uint _userCost = _shares * pos.cost / _totalPosShares;
        uint _userOi = _shares * pos.oi(_oi, _oiShares) / _totalPosShares;

        // TODO: think through edge case of underwater position ... and fee adjustments ...
        uint _feeAmount = _userNotional.mulUp(mothership.fee());

        uint _userValueAdjusted = _userNotional - _feeAmount;
        if (_userValueAdjusted > _userDebt) _userValueAdjusted -= _userDebt;
        else _userValueAdjusted = 0;

        fees += _feeAmount; // adds to fee pot, which is transferred on update

        // TODO: compare gas expenditure
        pos.debt -= _userDebt;
        pos.cost -= _userCost;
        pos.oiShares -= _userOiShares;
        // TODO: compare gas expenditure
        // positions[_positionId].debt -= _userDebt;
        // positions[_positionId].cost -= _userCost;
        // positions[_positionId].oiShares -= _userOiShares;

        emit Unwind(_positionId, _userOi, _userDebt);

        // mint/burn excess PnL = valueAdjusted - cost, accounting for need to also burn debt
        if (_userCost < _userValueAdjusted) {

            ovl.mint(address(this), _userValueAdjusted - _userCost);

        } else {

            ovl.burn(address(this), _userCost - _userValueAdjusted);

        }

        ovl.transfer(msg.sender, _userValueAdjusted);

        IOverlayV1Market(pos.market).exitOI(
            pos.compounding <= _tCompounding, 
            pos.isLong, 
            _userOi, 
            _userOiShares,
            _userCost < _userValueAdjusted ? _userValueAdjusted - _userCost : 0,
            _userCost < _userValueAdjusted ? 0 : _userValueAdjusted - _userCost
        );

        }

        _burn(msg.sender, _positionId, _shares);
 
    }

    /// @notice Liquidates an existing position
    function liquidate(
        uint256 _positionId,
        address _rewardsTo
    ) external {

        Position.Info storage pos = positions[_positionId];

        require(0 < pos.oiShares, "OVLV1:liquidated");

        bool _isLong = pos.isLong;

        (   uint _oi,
            uint _oiShares,
            uint _priceFrame,
            uint _tCompounding ) = IOverlayV1Market(pos.market).exitData(_isLong, pos.pricePoint);

        MarketInfo memory _marketInfo = marketInfo[pos.market];

        require(pos.isLiquidatable(
            _priceFrame,
            _oi,
            _oiShares,
            _marketInfo.marginMaintenance
        ), "OverlayV1: position not liquidatable");

        uint _value = pos.value(_priceFrame, _oi, _oiShares);

        IOverlayV1Market(pos.market).exitOI(
            pos.compounding <= _tCompounding, 
            _isLong, 
            pos.oi(_oi, _oiShares), 
            pos.oiShares,
            0,
            0
        );

        // TODO: which is better on gas
        pos.oiShares = 0;
        pos.debt = 0;
        // positions[positionId].oiShares = 0;

        uint _toForward = _value;
        uint _toReward = _toForward.mulUp(_marketInfo.marginRewardRate);

        liquidations += _toForward - _toReward;

        ovl.burn(address(this), pos.cost - _value);
        ovl.transfer(_rewardsTo, _toReward);

    }

}