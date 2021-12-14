// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../market/OverlayV1Comptroller.sol";
import "../interfaces/IUniswapV3Pool.sol";
import "../libraries/UniswapV3OracleLibrary/TickMath.sol";
import "../libraries/UniswapV3OracleLibrary/FullMath.sol";
import "../libraries/UniswapV3OracleLibrary/UniswapV3OracleLibraryV2.sol";
import "../libraries/FixedPoint.sol";

contract UniTest {

    event log(string k, uint v);
    event log(string k, int v);

    uint256 internal X96 = 0x1000000000000000000000000;

    address base0;
    address quote0;
    bool base0is0;
    uint128 baseAmount0;
    IUniswapV3Pool feed0;

    address base1;
    address quote1;
    uint128 baseAmount1;
    bool base1is0;
    IUniswapV3Pool feed1;

    uint128 multiplexBaseAmount;

    uint constant microWindow = 600;
    uint constant macroWindow = 3600;

    constructor (
        uint128 _baseAmount0,
        address _base0,
        address _quote0,
        address _feed0,
        uint128 _baseAmount1,
        address _base1,
        address _quote1,
        address _feed1,
        uint128 _multiplexBaseAmount
    ) { 

        baseAmount0 = _baseAmount0;
        base0 = _base0;
        quote0 = _quote0;
        base0is0 = IUniswapV3Pool(_feed0).token0() == _base0;
        feed0 = IUniswapV3Pool(_feed0);

        baseAmount1 = _baseAmount1;
        base1 = _base1;
        quote1 = _quote1;
        base1is0 = IUniswapV3Pool(_feed0).token0() == _base1;
        feed1 = IUniswapV3Pool(_feed1);

        multiplexBaseAmount = _multiplexBaseAmount;

    }

    function sanity () public view returns (string memory) {

        return "sanity";

    }

    function testMultiplex () public {

        int56[] memory _ticks;

        uint _usdEthPrice;
        int24 _usdEthTick;
        uint _ethBtcPrice;
        int24 _ethBtcTick;

        uint32[] memory _secondsAgo = new uint32[](2);
        _secondsAgo[1] = 1;

        ( _ticks, ) = IUniswapV3Pool(feed0).observe(_secondsAgo);

        _usdEthTick = int24(_ticks[0] - _ticks[1]);
        _usdEthPrice = OracleLibraryV2.getQuoteAtTick(
            _usdEthTick,
            baseAmount0, 
            base0, 
            quote0
        );

        ( _ticks, ) = IUniswapV3Pool(feed1).observe(_secondsAgo);

        _ethBtcTick = int24(_ticks[0] - _ticks[1]);
        _ethBtcPrice = OracleLibraryV2.getQuoteAtTick(
            _ethBtcTick,
            baseAmount1, 
            base1, 
            quote1
        );

        emit log("usd/eth tick", _usdEthTick);
        emit log("eth/btc tick", _ethBtcTick);

        emit log("usd/eth price", _usdEthPrice);
        emit log("eth/btc price", _ethBtcPrice);

        emit log("multiplexBaseAmount", multiplexBaseAmount);

        int24 _multiplexTick = _usdEthTick + _ethBtcTick;

        uint _multiplexPrice = getQuoteAtTick(
            _multiplexTick,
            multiplexBaseAmount,
            true
        );

        emit log("adding && reciprocal           ", _multiplexPrice);

        _multiplexPrice = getQuoteAtTick(
            _multiplexTick,
            multiplexBaseAmount,
            false
        );

        emit log("adding && !reciprocal          ", _multiplexPrice);

        _multiplexTick = _ethBtcTick - _usdEthTick;

        _multiplexPrice = getQuoteAtTick(
            _multiplexTick,
            multiplexBaseAmount,
            true
        );

        emit log("ethbtc - usdeth &&  reciprocal ", _multiplexPrice);

        _multiplexPrice = getQuoteAtTick(
            _multiplexTick,
            multiplexBaseAmount,
            false
        );

        emit log("ethbtc - usdeth && !reciprocal ", _multiplexPrice);

        _multiplexTick = _usdEthTick - _ethBtcTick;

        _multiplexPrice = getQuoteAtTick(
            _multiplexTick,
            multiplexBaseAmount,
            true
        );

        emit log("usdeth - ethbtc && reciprocal  ", _multiplexPrice);

        _multiplexPrice = getQuoteAtTick(
            _multiplexTick,
            multiplexBaseAmount,
            false
        );

        emit log("usdeth - ethbtc && !reciprocal  ", _multiplexPrice);

        emit log("1 if quote0>base0", quote0 > base0 ? 1 : 0);
        emit log("1 if quote1>base1", quote1 > base1 ? 1 : 0);

        emit log("multiplex tick", _multiplexTick);

    }

    function testPriceGrab () public {

        int56[] memory _ticks;
        uint160[] memory _liqs;

        uint _ovlPrice;
        uint _marketLiquidity;

        int24 _microTick;
        int24 _macroTick;

        uint32[] memory _secondsAgo = new uint32[](3);
        _secondsAgo[2] = uint32(macroWindow);
        _secondsAgo[1] = uint32(microWindow);

        ( _ticks, _liqs ) = IUniswapV3Pool(feed0).observe(_secondsAgo);

        _macroTick = int24((_ticks[0] - _ticks[2]) / int56(int32(int(macroWindow))));

        _microTick = int24((_ticks[0] - _ticks[1]) / int56(int32(int(microWindow))));

        uint _macro = OracleLibraryV2.getQuoteAtTick(
            _microTick, 
            baseAmount0, 
            base0, 
            quote0
        );

        uint _micro = OracleLibraryV2.getQuoteAtTick(
            _macroTick, 
            baseAmount0, 
            base0, 
            quote0
        );

    }


    function testPriceFetch () public returns (
        uint micro_,
        uint macro_,
        uint depth_
    ) {

        int56[] memory _ticks;
        uint160[] memory _liqs;

        uint _ovlPrice;
        uint _marketLiquidity;

        int24 _microTick;
        int24 _macroTick;

        {

            uint32[] memory _secondsAgo = new uint32[](3);
            _secondsAgo[2] = uint32(macroWindow);
            _secondsAgo[1] = uint32(microWindow);

            ( _ticks, _liqs ) = IUniswapV3Pool(feed0).observe(_secondsAgo);

            _macroTick = int24(( _ticks[0] - _ticks[2]) / int56(int32(int(macroWindow))));

            _microTick = int24((_ticks[0] - _ticks[1]) / int56(int32(int(microWindow))));

            uint _sqrtPrice = TickMath.getSqrtRatioAtTick(_microTick);

            uint _liquidity = (uint160(microWindow) << 128) / ( _liqs[0] - _liqs[1] );

            _marketLiquidity = base0is0
                ? ( uint256(_liquidity) << 96 ) / _sqrtPrice
                : FullMath.mulDiv(uint256(_liquidity), _sqrtPrice, X96);

        }


        {

            uint32[] memory _secondsAgo = new uint32[](2);

            _secondsAgo[1] = uint32(macroWindow);

            ( _ticks, ) = IUniswapV3Pool(feed1).observe(_secondsAgo);

            _ovlPrice = OracleLibraryV2.getQuoteAtTick(
                int24((_ticks[0] - _ticks[1]) / int56(int32(int(macroWindow)))),
                baseAmount1,
                base1,
                quote1
            );

        }

        return (
            OracleLibraryV2.getQuoteAtTick(_microTick, 1e18, base0, quote0),
            OracleLibraryV2.getQuoteAtTick(_macroTick, 1e18, base0, quote0),
            _ovlPrice
        );

    }

    function testUniLiq (
        uint32 _ago
    ) public view returns (
        uint x_,
        uint y_,
        uint z_
    ) {

        uint32[] memory _secondsAgo = new uint32[](2);
        _secondsAgo[0] = _ago;
        _secondsAgo[1] = 0;

        address f0t0 = feed0.token0();
        address f0t1 = feed0.token1();

        address f1t0 = feed1.token0();
        address f1t1 = feed1.token1();


        ( int56[] memory _ticks, uint160[] memory _invLiqs ) = feed0.observe(_secondsAgo);

        uint256 _sqrtPrice = TickMath.getSqrtRatioAtTick(
            int24((_ticks[1] - _ticks[0]) / int56(int32(_ago)))
        ); 

        // liquidity of USDC/ETH
        uint256 _liquidity = ( uint160(_ago) << 128 ) / ( _invLiqs[1] - _invLiqs[0] );

        uint _ethAmount = f0t0 == base0 
            ? ( uint256(_liquidity) << 96 ) / _sqrtPrice
            : FullMath.mulDiv(uint256(_liquidity), _sqrtPrice, 0x1000000000000000000000000);

        ( _ticks, ) = feed1.observe(_secondsAgo);

        uint _price = OracleLibraryV2.getQuoteAtTick(
            int24((_ticks[1] - _ticks[0]) / int56(int32(_ago))),
            baseAmount1,
            base1,
            quote1
        );

        x_ = _price;
        y_ = ( _ethAmount * 1e18 ) / _price;
        z_ = _ethAmount;

    }

    function thing () public view returns (int) {

        int _staticCap = 10;
        int _brrrrd = 3;
        int _brrrr = 5;

        _brrrrd = _staticCap < ( _brrrrd += _brrrr ) 
            ? _brrrrd
            : _staticCap;

        return _brrrrd;

    }


    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        bool reciprocal
    ) internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

        // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by itself
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = reciprocal
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = reciprocal
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }

}