// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./libraries/UniswapV3OracleLibrary/UniswapV3OracleLibraryV2.sol";
// import "./libraries/UniswapV3OracleLibrary/UniswapV3OracleLibrary.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./market/OverlayV1Market.sol";

contract OverlayV1UniswapV3Market is OverlayV1Market {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;

    address public immutable feed;
    // whether using price0Cumulative or price1Cumulative for TWAP
    bool public immutable isPrice0;
    // window size for sliding window TWAP calc
    uint256 public immutable macroWindow;
    uint256 public immutable microWindow;

    uint128 internal immutable amountIn;
    address private immutable token0;
    address private immutable token1;

    constructor(
        address _ovl,
        address _uniV3Pool,
        uint256 _updatePeriod,
        uint256 _compoundingPeriod,
        uint256 _printWindow,
        uint256 _macroWindow,
        uint256 _microWindow,
        uint144 _oiCap,
        uint112 _fundingK,
        uint8   _leverageMax,
        uint128 _amountIn,
        bool    _isPrice0
    ) OverlayV1Market(
        _ovl,
        _updatePeriod,
        _compoundingPeriod,
        _printWindow,
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

    function twapPrice(
        uint secondsAgoStart, 
        uint secondsAgoEnd
    ) public view returns (uint256 price_)   {

        int24 tick = OracleLibraryV2.consult(
            feed, 
            uint32(secondsAgoStart), 
            uint32(secondsAgoEnd)
        );

        price_ = OracleLibraryV2.getQuoteAtTick(
            tick,
            uint128(amountIn),
            isPrice0 ? token0 : token1,
            isPrice0 ? token1 : token0
        );

    }

    uint public toUpdate;
    uint public updated;
    uint public compounded;

    uint public staticSpreadAsk; // this is going to be some amount of basis points
    uint public staticSpreadBid; // this is going to be some amount of basis points

    function NOW () external view returns (uint) { return block.timestamp; }

    function price (uint _at) public view returns (PricePoint memory) { 

        uint twapPrice_ = twapPrice(_at - macroWindow, _at);
        uint _spreadPrice = twapPrice(_at - microWindow, _at);

        // uint ask_ = max(twapPrice_, _spreadPrice);
        // uint bid_ = min(twapPrice_, _spreadPrice);
        uint ask_ = twapPrice_;
        uint bid_ = twapPrice_;

        // formula for ask
        // bid = min(twap,spread) * e ^ -(staticSpread + (impactParam * impactShort))
        // ask = max(twap,spread) * e ^ (staticSpread + (impactParam * impactLong))

        ask_ = ask_ * staticSpreadAsk / RESOLUTION;
        bid_ = bid_ * staticSpreadBid / RESOLUTION;

        ( uint _longImpact, uint _shortImpact ) = senseImpact();

        // ask_ = e ** _longImpact
        
        // kkimpact

        return PricePoint(
            bid_,
            ask_,
            twapPrice_
        );

    }

    function marketImpact () internal view returns (uint) {

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
        uint112 _k = fundingK;
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
