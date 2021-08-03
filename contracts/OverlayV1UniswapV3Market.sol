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

    function epochs (
        uint _time,
        uint _from,
        uint _between
    ) view internal returns (
        uint epochsThen_,
        uint epochsNow_,
        uint tEpoch_,
        uint t1Epoch_
    ) { 

        uint _updatePeriod = updatePeriod;

        if (_between < _time) {

            epochsThen_ = ( _between - _from ) / _updatePeriod;

            epochsNow_ = ( _time - _between ) / _updatePeriod;

        } else {

            epochsNow_ = ( _time - _from ) / _updatePeriod;

        }
        
        tEpoch_ = _from + ( ( epochsThen_ + epochsNow_ ) * _updatePeriod );

        t1Epoch_ = tEpoch_ + _updatePeriod;

    }

    function staticUpdate () internal override returns (bool updated_) {

        uint _toUpdate = toUpdate;

        (   uint _epochsThen,,, ) = epochs(block.timestamp, updated, _toUpdate);

        // only update if there is a position to update
        if (0 < _epochsThen) {
            uint _price = lastPrice(_toUpdate - windowSize, _toUpdate);
            updateFunding(_epochsThen, _price);
            setPricePointCurrent(_price);
            updated = _toUpdate;
            toUpdate = type(uint256).max;
            updated_ = true;
        }

    }

    function entryUpdate () internal override {

        uint _toUpdate = toUpdate;

        (   uint _epochsThen,,,
            uint _tp1Epoch ) = epochs(block.timestamp, updated, _toUpdate);

        if (0 < _epochsThen) {
            uint _price = lastPrice(_toUpdate - windowSize, _toUpdate);
            updateFunding(_epochsNow, _price);
            setPricePointCurrent(_price);
            updated = _toUpdate;
        }

        if (_toUpdate != _tp1Epoch) toUpdate = _tp1Epoch;

    }

    function exitUpdate () internal override {

        uint _toUpdate = toUpdate;

        (   uint _epochsThen,
            uint _epochsNow,
            uint _tEpoch, ) = epochs(block.timestamp, updated, _toUpdate);
            
        if (0 < _epochsThen) {

            uint _price = lastPrice(_toUpdate - windowSize, _toUpdate);
            updateFunding(_epochsThen, _price);
            setPricePointCurrent(_price);

        }

        if (0 < _epochsNow) { 

            uint _price = lastPrice(_tEpoch - windowSize, _tEpoch);
            updateFunding(_epochsNow, _price);
            setPricePointCurrent(_price);

            updated = _tEpoch;
            toUpdate = type(uint256).max;

        }

    }

}
