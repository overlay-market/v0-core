// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./libraries/FixedPoint.sol";
import "./libraries/UniswapV3OracleLibrary/UniswapV3OracleLibraryV2.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./market/OverlayV1Market.sol";

contract OverlayV1UniswapV3Market is OverlayV1Market {

    using FixedPoint for uint256;

    address public immutable feed;
    bool public immutable isPrice0;

    uint256 public immutable macroWindow; // window size for main TWAP
    uint256 public immutable microWindow; // window size for bid/ask TWAP

    uint128 internal immutable amountIn;
    address private immutable token0;
    address private immutable token1;

    uint256 internal constant EULER = 0x25B946EBC0B36351;
    uint256 internal constant INVERSE_EULER = 0x51AF86713316A9A;

    constructor(
        address _ovl,
        address _uniV3Pool,
        uint256 _updatePeriod,
        uint256 _compoundingPeriod,
        uint256 _brrrrFade,
        uint256 _macroWindow,
        uint256 _microWindow,
        uint256 _oiCap,
        uint256 _fundingK,
        uint256 _leverageMax,
        uint128 _amountIn,
        bool    _isPrice0
    ) OverlayV1Market(
        _ovl,
        _updatePeriod,
        _compoundingPeriod,
        _brrrrFade,
        _microWindow,
        _oiCap,
        _fundingK,
        _leverageMax
    ) {

        // immutables
        feed = _uniV3Pool;
        isPrice0 = _isPrice0;
        macroWindow = _macroWindow;
        microWindow = _microWindow;


        amountIn = _amountIn;
        address _token0 = IUniswapV3Pool(_uniV3Pool).token0();
        address _token1 = IUniswapV3Pool(_uniV3Pool).token1();

        token0 = _token0;
        token1 = _token1;

        int24 tick = OracleLibraryV2.consult(
            _uniV3Pool, 
            uint32(_macroWindow),
            uint32(0)
        );

        uint _price = OracleLibraryV2.getQuoteAtTick(
            tick,
            uint128(_amountIn),
            _isPrice0 ? _token0 : _token1,
            _isPrice0 ? _token1 : _token0
        );

        setPricePointCurrent(PricePoint(_price, _price, _price));

        updated = block.timestamp;
        toUpdate = type(uint256).max;
        compounded = block.timestamp;

    }

    uint public toUpdate;
    uint public updated;
    uint public compounded;

    uint public staticSpreadAsk; // this is going to be some amount of basis points
    uint public staticSpreadBid; // this is going to be some amount of basis points

    function price (uint _at) public view returns (PricePoint memory) { 

        uint32[] memory _secondsAgo = new uint32[](3);
        _secondsAgo[0] = _at - macroWindow;
        _secondsAgo[1] = _at - microWindow;
        _secondsAgo[2] = _at;

        int56[] memory ticks = IUniswapV3Pool(feed).observe(_secondsAgo);

        int24 _macroTick = int24((_ticks[2] - _ticks[0]) / int56(int32(macroWindow)));
        int24 _macroTick = int24((_ticks[2] - _ticks[1]) / int56(int32(microWindow)));

        uint _macroPrice = OracleLibraryV2.getQuoteAtTick(
            _macroTick,
            uint128(amountIn),
            isPrice0 ? token0 : token1,
            isPrice0 ? token1 : token0
        );

        uint _microPrice = OracleLibraryV2.getQuoteAtTick(
            _macroTick,
            uint128(amountIn),
            isPrice0 ? token0 : token1,
            isPrice0 ? token1 : token0
        );

        uint _ask = Math.max(_macroPrice, _microPrice).mulUp(INVERSE_EULER.powUp(squiggly));
        uint _bid = Math.min(_macroPrice, _microPrice).mulDown(EULER.powUp(squiggly));

        return PricePoint(
            bid_,
            ask_,
            _macroPrice
        );

    }

    function epochs (
        uint _time,
        uint _from,
        uint _between
    ) public view returns (
        uint updatesThen_,
        uint updatesNow_,
        uint tUpdate_,
        uint t1Update_,
        uint compoundings_,
        uint tCompounding_,
        uint t1Compounding_
    ) { 

        uint _updatePeriod = updatePeriod;
        uint _compoundPeriod = compoundingPeriod;
        uint _compounded = compounded;

        if (_between < _time) {

            updatesThen_ = ( _between - _from ) / _updatePeriod;

            updatesNow_ = ( _time - _between ) / _updatePeriod;

        } else {

            updatesNow_ = ( _time - _from ) / _updatePeriod;

        }
        
        tUpdate_ = _from + ( ( updatesThen_ + updatesNow_ ) * _updatePeriod );

        t1Update_ = tUpdate_ + _updatePeriod;

        compoundings_ = ( _time - compounded ) / _compoundPeriod;

        tCompounding_ = _compounded + ( compoundings_ * _compoundPeriod );

        t1Compounding_ = tCompounding_ + _compoundPeriod;

    }

    function staticUpdate () internal override returns (bool updated_) {

        uint _toUpdate = toUpdate;
        uint _updated = updated;

        (   uint _updatesThen,,,,
            uint _compoundings,
            uint _tCompounding, ) = epochs(block.timestamp, updated, _toUpdate);

        // only update if there is a position to update
        if (0 < _updatesThen) {
            uint _then = block.timestamp - _toUpdate;
            PricePoint memory _price = price(_then);
            setPricePointCurrent(_price);
            updated = _toUpdate;
            toUpdate = type(uint256).max;
            updated_ = true;
        }

        if (0 < _compoundings) {
            updateFunding(_compoundings);
            compounded = _tCompounding;
        }

    }

    function entryUpdate () internal override returns (
        uint256 t1Compounding_
    ) {

        uint _toUpdate = toUpdate;

        (   uint _updatesThen,,,
            uint _tp1Update,
            uint _compoundings,
            uint _tCompounding,
            uint _t1Compounding ) = epochs(block.timestamp, updated, _toUpdate);

        if (0 < _updatesThen) {
            uint _then = block.timestamp - _toUpdate;
            PricePoint memory _price = price(_then);
            setPricePointCurrent(_price);
            updated = _toUpdate;
        }

        if (0 < _compoundings) {
            updateFunding(_compoundings);
            compounded = _tCompounding;
        }

        if (_toUpdate != _tp1Update) toUpdate = _tp1Update;

        t1Compounding_ = _t1Compounding;

    }

    function exitUpdate () internal override returns (uint tCompounding_) {

        uint _toUpdate = toUpdate;

        (   uint _updatesThen,
            uint _updatesNow,
            uint _tUpdate,,
            uint _compoundings,
            uint _tCompounding, ) = epochs(block.timestamp, updated, _toUpdate);

            
        if (0 < _updatesThen) {

            uint _then = block.timestamp - _toUpdate;
            PricePoint memory _price = price(_then);
            setPricePointCurrent(_price);

        }

        if (0 < _updatesNow) { 

            uint _then = block.timestamp - _tUpdate;
            PricePoint memory _price = price(_then);
            setPricePointCurrent(_price);

            updated = _tUpdate;
            toUpdate = type(uint256).max;

        }

        if (0 < _compoundings) {

            updateFunding(1);
            updateFunding(_compoundings - 1);

        }

        tCompounding_ = _tCompounding;

    }

    function oi () public view returns (uint oiLong_, uint oiShort_) {

        ( ,,,,uint _compoundings,, ) = epochs(block.timestamp, updated, toUpdate);

        oiLong_ = __oiLong__;
        oiShort_ = __oiShort__;
        uint _k = fundingK;
        uint _queuedOiLong = queuedOiLong;
        uint _queuedOiShort = queuedOiShort;

        if (0 < _compoundings) {

            ( oiLong_, oiShort_, ) = computeFunding(
                oiLong_,
                oiShort_,
                1,
                _k
            );

            ( oiLong_, oiShort_, ) = computeFunding(
                oiLong_ += _queuedOiLong,
                oiShort_ += _queuedOiShort,
                _compoundings - 1,
                _k
            );

        } else {

            oiLong_ += _queuedOiLong;
            oiShort_ += _queuedOiShort;

        }

    }

    function oiLong () external returns (uint oiLong_) {
        (   oiLong_, ) = oi();
    }

    function oiShort () external view returns (uint oiShort_) {
        (  ,oiShort_ ) = oi();
    }

}
