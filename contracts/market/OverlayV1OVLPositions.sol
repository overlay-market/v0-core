
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../libraries/PositionV2.sol";

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "../interfaces/IOverlayV1Market.sol";
import "../interfaces/IOverlayV1Factory.sol";
import "../interfaces/IOverlayToken.sol";

contract OverlayV1OVLPositions is ERC1155 {

    using PositionV2 for PositionV2.Info;

    // TODO: do we have a struct for markets?
    struct Market { uint _marginAdjustment; }

    // mapping from position (erc1155) id to total shares issued of position
    mapping(uint256 => uint256) public totalPositionShares;

    mapping (address => uint) marginAdjustments;
    mapping (address => bool) supportedMarket;
    mapping (address => mapping(uint => uint)) internal queuedPositionLongs;
    mapping (address => mapping(uint => uint)) internal queuedPositionShorts;
    PositionV2.Info[] public positions;

    uint16 public constant MIN_COLLAT = 10**4;
    uint constant RESOLUTION = 1e4;

    uint nextPositionId;

    IOverlayToken public ovl;
    IOverlayV1Factory public factory;

    uint256 public fees;

    event Build(uint256 positionId, uint256 oi, uint256 debt);
    event Unwind(uint256 positionId, uint256 oi, uint256 debt);
    event Liquidate(address indexed rewarded, uint256 reward);
    constructor (
        string memory _uri,
        address _ovl
    ) ERC1155(_uri) { 

        ovl = IOverlayToken(_ovl);

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

        PositionV2.Info storage position = positions[positionId_];

        if (position.pricePoint < _pricePointCurrent) {

            positions.push(PositionV2.Info({
                market: _market,
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

        (   uint _freeOi,
            uint _maxLev,
            uint _pricePointCurrent ) = IOverlayV1Market(_market).entryData(_isLong);

        require(_leverage <= _maxLev, "OVLV1:max<lev");
        require(_collateral < MIN_COLLAT, "OVLV1:collat<min");

        uint _positionId = getQueuedPositionId(
            _market, 
            _isLong, 
            _leverage, 
            _pricePointCurrent
        );

        PositionV2.Info storage position = positions[_positionId];

        uint _oiAdjusted;

        {
        uint _oi = _collateral * _leverage;
        uint _fee = ( _oi * factory.fee() ) / RESOLUTION;
        _oiAdjusted = _oi - _fee;
        uint _collateralAdjusted = _oiAdjusted / _leverage;
        uint _debtAdjusted = _oiAdjusted - _collateralAdjusted;

        fees += _fee;

        position.oiShares += _oiAdjusted;
        position.debt += _debtAdjusted;
        position.cost += _collateralAdjusted;

        }

        IOverlayV1Market(_market).enterOI(_isLong, _oiAdjusted);
        ovl.transferFrom(msg.sender, address(this), _collateral);
        mint(msg.sender, _positionId, _oiAdjusted, ""); // WARNING: must be last b/c erc1155 callback

        }

    /// @notice Unwinds shares of an existing position
    function unwind(
        uint256 _positionId,
        uint256 _shares
    ) external {

        require( 0 < _shares && _shares <= balanceOf(msg.sender, _positionId), "OVLV1:!shares");

        PositionV2.Info storage pos = positions[_positionId];

        bool _isLong = pos.isLong;

        (   uint _oi,
            uint _oiShares,
            uint _totalOiShares,
            uint _priceEntry,
            uint _priceExit ) = IOverlayV1Market(pos.market).exitData(_isLong, pos.pricePoint);
        
        uint _valueAdjusted;
        uint _cost;

        {

        _valueAdjusted = _shares * pos.notional(_priceEntry, _priceExit, _oi, _oiShares) / _totalOiShares;

        uint _debt = _shares * pos.debt / _totalOiShares; // TODO: read from storage here
        _cost = _shares * pos.cost / _totalOiShares; // TODO: read from storage here

        // TODO: think through edge case of underwater position ... and fee adjustments ...
        uint feeAmount = ( _valueAdjusted * factory.fee() ) / RESOLUTION;
        _valueAdjusted = _valueAdjusted - feeAmount;
        _valueAdjusted = _valueAdjusted > _debt ? _valueAdjusted - _debt : 0; // floor in case underwater, and protocol loses out on any maintenance margin

        // effects
        fees += feeAmount; // adds to fee pot, which is transferred on update

        pos.debt -= _debt;
        pos.cost -= _cost;

        uint _posOiShares = _shares * pos.oiShares / _totalOiShares;
        uint _posOi = pos.openInterest(_oi, _oiShares);
        _posOi = _shares * _posOi / _totalOiShares;
        pos.oiShares -= _posOiShares;

        IOverlayV1Market(pos.market).exitOI(_isLong, _posOi, _posOiShares);
        emit Unwind(_positionId, _posOi, _debt);
        }

        // events

        // interactions
        // mint/burn excess PnL = valueAdjusted - cost, accounting for need to also burn debt
        if (_cost < _valueAdjusted) ovl.mint(address(this), _valueAdjusted - _cost);
        else ovl.burn(address(this), _cost - _valueAdjusted);

        burn(msg.sender, _positionId, _shares);
        ovl.transfer(msg.sender, _valueAdjusted);
 
    }

    function liquidate(
        uint256 positionId,
        address rewardsTo
    ) external {

    }

    /// @notice Mint overrides erc1155 _mint to track total shares issued for given position id
    function mint(address account, uint256 id, uint256 shares, bytes memory data) internal {
        totalPositionShares[id] += shares;
        _mint(account, id, shares, data);
    }

    /// @notice Burn overrides erc1155 _burn to track total shares issued for given position id
    function burn(address account, uint256 id, uint256 shares) internal {
        uint256 totalShares = totalPositionShares[id];
        require(totalShares >= shares, "OverlayV1: burn shares exceeds total");
        totalPositionShares[id] = totalShares - shares;
        _burn(account, id, shares);
    }


}