
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../libraries/Position.sol";

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "../interfaces/IOverlayV1Market.sol";

contract OverlayV1OVLPositions is ERC1155 {

    // TODO: do we have a struct for markets?
    struct Market { uint _marginAdjustment; }

    mapping (address => uint) marginAdjustments;
    mapping (address => bool) supportedMarket;
    mapping (address => mapping(uint => uint)) internal queuedPositionLongs;
    mapping (address => mapping(uint => uint)) internal queuedPositionShorts;
    Position.Info[] public positions;

    uint nextPositionId;


    constructor (
        string memory _uri,
        address _ovl
    ) ERC1155(_uri) {

    }

    function addMarket (
        address _market,
        uint _marginAdjustment
    ) external {

        marginAdjustments[_market] = _marginAdjustment;

    }

    function getQueuedPositionId (
        address _market,
        bool _isLong,
        uint _leverage,
        uint _pricePointCurrent
    ) internal returns (uint positionId_) {

        mapping(uint=>uint) storage _queuedPositions = _isLong 
            ? queuedPositionLongs[_market]
            : queuedPositionShorts[_market];

        positionId_ = _queuedPositions[_leverage];

        Position.Info storage _position = positions[positionId_];

        if (_position.pricePoint < _pricePointCurrent) {
            positions.push(Position.Info({
                isLong: _isLong,
                leverage: _leverage,
                pricePoint: _pricePointCurrent,
                oiShares: 0,
                debt: 0,
                cost: 0
            }));

            positionId_ = positions.length;

            _queuedPositions[_leverage] = positionId_;

        }

    }

    function build(
        address _market,
        uint256 _collateral,
        bool _isLong,
        uint256 _leverage,
        address _rewardsTo
    ) external {

        ( ,,uint _freeOi,
            uint _maxLev,
            uint _pricePointCurrent ) = IOverlayV1Market(_market).data(_isLong);

        require(_leverage <= _maxLev, "OVLV1:max<lev");
        require(_collateral < MIN_COLLAT, "OVLV1:collat<min");

        uint _oi = _collateral * _leverage;
        uint _fee = ( _oi * factory.fee() ) / RESOLUTION;
        uint _oiAdjusted = _oi - _fee;
        uint _collateralAdjusted = _oiAdjusted / _leverage;
        uint _debtAdjusted = _oiAdjusted - _collateralAdjusted;

        fees += _fee;

        Position.Info storage position = positions[
            getPositionId( _market, _isLong, _leverage, _pricePointCurrent);
        ];

        position.oiShares += _oiAdjusted;
        position.debt += _debtAdjusted;
        position.cost += _collateralAdjusted;

        IOverlayV1Market(market).increaseOI(_isLong, _oiAdjusted);
        ovl.transferFrom(msg.sender, address(this), collateralAmount);
        // WARNING: _mint should be last bc erc1155 callback; mint shares based on OI contribution
        mint(msg.sender, positionId, oiAdjusted, "");
    }


    /// @notice Unwinds shares of an existing position
    function unwind(
        uint256 positionId,
        uint256 shares,
        address rewardsTo
    ) external {


    }

    function liquidate(
        uint256 positionId,
        address rewardsTo
    ) external {

    }

}