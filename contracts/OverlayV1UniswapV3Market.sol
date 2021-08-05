// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

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
    uint256 public immutable windowSize;

    uint128 internal immutable amountIn;
    address private immutable token0;
    address private immutable token1;

    constructor(
        address _ovl,
        address _uniV3Pool,
        uint256 _updatePeriod,
        uint256 _compoundingPeriod,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator,
        uint8   _leverageMax,
        uint256 _windowSize,
        uint128 _amountIn,
        bool    _isPrice0
    ) OverlayV1Market(
        _ovl,
        _updatePeriod,
        _compoundingPeriod,
        _oiCap,
        _fundingKNumerator,
        _fundingKDenominator,
        _leverageMax
    ) {
        // immutables
        feed = _uniV3Pool;
        isPrice0 = _isPrice0;
        windowSize = _windowSize;

        amountIn = _amountIn;
        token0 = IUniswapV3Pool(_uniV3Pool).token0();
        token1 = IUniswapV3Pool(_uniV3Pool).token1();

    }

    function lastPrice(uint secondsAgoStart, uint secondsAgoEnd) public view returns (uint256 price_)   {

        int24 tick = OracleLibraryV2.consult(feed, uint32(secondsAgoStart), uint32(secondsAgoEnd));

        price_ = OracleLibraryV2.getQuoteAtTick(
            tick,
            uint128(amountIn),
            isPrice0 ? token0 : token1,
            isPrice0 ? token1 : token0
        );

    }

    uint toUpdate;
    uint updated;
    uint compounded;

    function epochs (
        uint _time,
        uint _from,
        uint _between
    ) view internal returns (
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

        (   uint _updatesThen,,,,
            uint _compoundings,
            uint _tCompounding, ) = epochs(block.timestamp, updated, _toUpdate);

        // only update if there is a position to update
        if (0 < _updatesThen) {
            uint _price = lastPrice(_toUpdate - windowSize, _toUpdate);
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

    function entryUpdate () internal override returns (uint256 t1Compounding_) {

        uint _toUpdate = toUpdate;

        (   uint _updatesThen,,,
            uint _tp1Update,
            uint _compoundings,
            uint _tCompounding,
            uint _t1Compounding ) = epochs(block.timestamp, updated, _toUpdate);

        if (0 < _updatesThen) {
            uint _price = lastPrice(_toUpdate - windowSize, _toUpdate);
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

        uint _price;
            
        if (0 < _updatesThen) {

            _price = lastPrice(_toUpdate - windowSize, _toUpdate);
            setPricePointCurrent(_price);

        }

        if (0 < _updatesNow) { 

            _price = lastPrice(_tUpdate - windowSize, _tUpdate);
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
        uint112 _kNumerator = fundingKNumerator;
        uint112 _kDenominator = fundingKDenominator;

        if (_compoundings < 0) {

            ( oiLong_, oiShort_, ) = computeFunding(
                oiLong_,
                oiShort_,
                1,
                _kNumerator,
                _kDenominator
            );

            ( oiLong_, oiShort_, ) = computeFunding(
                oiLong_,
                oiShort_,
                _compoundings - 1,
                _kNumerator,
                _kDenominator
            );

        }


    }

    function oiLong () external returns (uint oiLong_) {
        (   oiLong_, ) = oi();
    }

    function oiShort () external view returns (uint oiShort_) {
        (  ,oiShort_ ) = oi();
    }

}
