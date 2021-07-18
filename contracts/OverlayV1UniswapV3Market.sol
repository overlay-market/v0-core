// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./libraries/UniswapV3OracleLibrary/UniswapV3OracleLibrary.sol";
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
    // ideally value of ONE for tokenIn
    uint256 public immutable amountIn;

    address private immutable token0;
    address private immutable token1;

    constructor(
        address _ovl,
        address _uniV3Pool,
        uint256 _updatePeriod,
        uint8 _leverageMax,
        uint16 _marginAdjustment,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator,
        bool _isPrice0,
        uint256 _windowSize,
        uint256 _amountIn
    ) OverlayV1Market(
        "https://metadata.overlay.exchange/v1/uniV3/{id}.json",
        _ovl,
        _updatePeriod,
        _leverageMax,
        _marginAdjustment,
        _oiCap,
        _fundingKNumerator,
        _fundingKDenominator
    ) {
        // immutables
        feed = _uniV3Pool;
        isPrice0 = _isPrice0;
        windowSize = _windowSize;
        amountIn = _amountIn;

        token0 = IUniswapV3Pool(_uniV3Pool).token0();
        token1 = IUniswapV3Pool(_uniV3Pool).token1();

    }

    function lastPrice() public view returns (uint256 price_)   {

        int24 tick = OracleLibrary.consult(feed, uint32(windowSize));

        price_ = OracleLibrary.getQuoteAtTick(
            tick,
            uint128(amountIn),
            isPrice0 ? token0 : token1,
            isPrice0 ? token1 : token0
        );

    }

    /// @dev Override for Mirin market feed to compute and set TWAP for latest price point index
    function fetchPricePoint() internal virtual override returns (uint price) {
        price = lastPrice();
        setPricePointCurrent(price);
    }
}
