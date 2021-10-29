// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../market/OverlayV1Comptroller.sol";
import "../interfaces/IOverlayToken.sol";
import "../interfaces/IUniswapV3Pool.sol";
import "../libraries/UniswapV3OracleLibrary/UniswapV3OracleLibraryV2.sol";
import "../libraries/FixedPoint.sol";

contract ComptrollerShim is OverlayV1Comptroller {

    using FixedPoint for uint256;

    uint256 internal X96 = 0x1000000000000000000000000;

    IOverlayToken public ovl;

    address public ovlFeed;
    address public marketFeed;
    address public eth;

    bool public ethIs0;

    uint public macroWindow;
    uint public microWindow;

    constructor (
        uint _impactWindow,
        uint _lmbda,
        uint _staticCap,
        uint _brrrrdExpected,
        uint _brrrrdWindowMacro,
        uint _brrrrdWindowMicro,
        uint _priceWindowMacro,
        uint _priceWindowMicro,
        address _marketFeed,
        address _ovlFeed,
        address _ovl,
        address _eth
    ) {

        impactWindow = _impactWindow;
        lmbda = _lmbda;
        staticCap = _staticCap;
        brrrrdExpected = _brrrrdExpected;
        brrrrdWindowMacro = _brrrrdWindowMacro;
        brrrrdWindowMicro = _brrrrdWindowMicro;
        macroWindow = _priceWindowMacro;
        microWindow = _priceWindowMicro;
        marketFeed = _marketFeed;
        ovlFeed = _ovlFeed;
        ethIs0 = IUniswapV3Pool(_ovlFeed).token0() == _eth;

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

    function setRoller (
        uint index,
        uint __timestamp,
        uint __longPressure,
        uint __shortPressure
    ) public {

        impactRollers[index].time = __timestamp;
        impactRollers[index].ying = __longPressure;
        impactRollers[index].yang = __shortPressure;

    }

    function viewScry(
        uint _ago
    ) public view returns (
        Roller memory rollerNow_,
        Roller memory rollerThen_
    ) {

        uint lastMoment;

        (   lastMoment,
            rollerNow_,
            rollerThen_ ) = scry(impactRollers, impactCycloid, _ago);


    }

    function brrrrBatch (
        uint[] memory _brrrr,
        uint[] memory _antiBrrrr
    ) public {

        uint len = _brrrr.length;

        for (uint i = 0; i < len; i++) {

            brrrr( _brrrr[i], _antiBrrrr[i] );

        }

    }

    function impactBatch (
        bool[] memory _isLong,
        uint[] memory _oi
    ) public returns (
        uint impact_
    ) {

        uint len = _isLong.length;

        for (uint i = 0; i < len; i++) {

            ( impact_, ) = intake(_isLong[i], _oi[i]);

        }

    }

    function viewImpact (
        bool _isLong,
        uint _oi
    ) public view returns (
        uint impact_
    ) {

        ( ,,impact_, ) = _intake(_isLong, _oi);

    }

}