// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./libraries/FixedPoint.sol";
import "./libraries/UniswapV3OracleLibrary/UniswapV3OracleLibraryV2.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./market/OverlayV1Market.sol";

contract OverlayV1UniswapV3Market is OverlayV1Market {

    using FixedPoint for uint256;

    uint256 internal X96 = 0x1000000000000000000000000;

    uint public toUpdate;
    uint public updated;
    uint public compounded;

    uint256 public immutable macroWindow; // window size for main TWAP
    uint256 public immutable microWindow; // window size for bid/ask TWAP

    address public immutable marketFeed;
    address public immutable ovlFeed;
    address public immutable base;
    address public immutable quote;
    uint128 internal immutable amountIn;

    address internal immutable eth;
    bool internal immutable ethIs0;

    constructor(
        address _mothership,
        address _ovlFeed,
        address _marketFeed,
        address _quote,
        address _eth,
        uint128 _amountIn,
        uint256 _macroWindow,
        uint256 _microWindow
    ) OverlayV1Market(
        _mothership
    ) {

        // immutables
        eth = _eth;
        ethIs0 = IUniswapV3Pool(_ovlFeed).token0() == _eth;
        ovlFeed = _ovlFeed;
        marketFeed = _marketFeed;
        amountIn = _amountIn;
        macroWindow = _macroWindow;
        microWindow = _microWindow;

        address _token0 = IUniswapV3Pool(_marketFeed).token0();
        address _token1 = IUniswapV3Pool(_marketFeed).token1();

        base = _token0 != _quote ? _token0 : _token1;
        quote = _token0 == _quote ? _token0 : _token1;

        int24 _tick = OracleLibraryV2.consult(
            _marketFeed, 
            uint32(_macroWindow),
            uint32(0)
        );

        uint _price = OracleLibraryV2.getQuoteAtTick(
            _tick,
            uint128(_amountIn),
            _token0 != _quote ? _token0 : _token1,
            _token0 == _quote ? _token0 : _token1
        );

        setPricePointCurrent(PricePoint(_price, _price, _price));

        toUpdate = type(uint256).max;
        updated = block.timestamp;
        compounded = block.timestamp;

    }

    function price (
        uint _ago
    ) public view returns (
        PricePoint memory
    ) { 

        uint32[] memory _secondsAgo = new uint32[](3);
        _secondsAgo[0] = uint32(_ago - macroWindow);
        _secondsAgo[1] = uint32(_ago - microWindow);
        _secondsAgo[2] = uint32(_ago);

        ( int56[] memory _ticks, ) = IUniswapV3Pool(marketFeed).observe(_secondsAgo);

        uint _macroPrice = OracleLibraryV2.getQuoteAtTick(
            int24((_ticks[2] - _ticks[0]) / int56(int32(int(macroWindow)))),
            amountIn,
            base,
            quote
        );

        uint _microPrice = OracleLibraryV2.getQuoteAtTick(
            int24((_ticks[2] - _ticks[1]) / int56(int32(int(microWindow)))),
            amountIn,
            base,
            quote
        );

        return insertSpread(_microPrice, _macroPrice);

    }

    function depth () internal virtual override view returns (uint256 depth_) {

        uint32[] memory _secondsAgo = new uint32[](2);
        _secondsAgo[0] = uint32(microWindow);
        _secondsAgo[1] = 0;

        ( int56[] memory _ticks, uint160[] memory _invLiqs ) = IUniswapV3Pool(marketFeed).observe(_secondsAgo);

        uint256 _sqrtPrice = TickMath.getSqrtRatioAtTick(
            int24((_ticks[1] - _ticks[0]) / int56(int32(int(microWindow))))
        );

        uint256 _liquidity = (uint160(microWindow) << 128) / ( _invLiqs[1] - _invLiqs[0] );

        uint _ethAmount = ethIs0
            ? ( uint256(_liquidity) << 96 ) / _sqrtPrice
            : FullMath.mulDiv(uint256(_liquidity), _sqrtPrice, X96);

        ( _ticks, ) = IUniswapV3Pool(ovlFeed).observe(_secondsAgo);

        uint _price = OracleLibraryV2.getQuoteAtTick(
            int24((_ticks[1] - _ticks[0]) / int56(int32(int(microWindow)))),
            1e18,
            address(ovl),
            eth
        );

        depth_ = lmbda.mulUp(( _ethAmount * 1e18 ) / _price).divDown(2e18);

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
            uint _tCompounding, ) = epochs(block.timestamp, _updated, _toUpdate);

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
        uint _now = block.timestamp;

        (   uint _updatesThen,
            uint _updatesNow,
            uint _tUpdate,,
            uint _compoundings,
            uint _tCompounding, ) = epochs(_now, updated, _toUpdate);

            
        if (0 < _updatesThen) {

            uint _then = _now - _toUpdate;
            PricePoint memory _price = price(_then);
            setPricePointCurrent(_price);

        }

        if (0 < _updatesNow) { 

            uint _then = _now - _tUpdate;
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
        uint _k = k;
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

    function oiLong () external view returns (uint oiLong_) {
        (   oiLong_, ) = oi();
    }

    function oiShort () external view returns (uint oiShort_) {
        (  ,oiShort_ ) = oi();
    }

    function priceFrame (
        bool _isLong,
        uint _entryIndex
    ) external view returns (
        uint256 priceFrame_
    ) {

        uint _toUpdate = toUpdate;

        uint _now = block.timestamp;

        uint256 _currentIndex = pricePoints.length;

        (   uint _updatesThen,,
            uint _tUpdate,,,, ) = epochs(_now, updated, _toUpdate);

        PricePoint memory _priceEntry;
        PricePoint memory _priceExit;

        if (_entryIndex < _currentIndex) {

            _priceEntry = pricePoints[_entryIndex];

        } else if (0 < _updatesThen ) {

            _priceEntry = price(_now - _toUpdate);

        } else revert("OVLV1:!settled");

        _priceExit = price(_now - _tUpdate);

        priceFrame_ = _isLong
            ? Math.min(_priceExit.bid / _priceEntry.ask, priceFrameCap)
            : _priceExit.ask / _priceEntry.bid;

    }

}
