// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./libraries/FixedPoint.sol";
import "./interfaces/IMirinOracle.sol";

import "./OverlayMarket.sol";

contract OverlayMirinMarket is OverlayMarket {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;

    address public immutable mirinPool;
    bool public immutable isPrice0;
    // window size for sliding window TWAP calc
    uint256 public immutable windowSize;
    // ideally value of ONE for tokenIn
    uint256 public immutable amountIn;

    constructor(
        address _ovl,
        address _mirinPool,
        bool _isPrice0,
        uint256 _updatePeriod,
        uint256 _windowSize,
        uint8 _leverageMax,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator,
        uint256 _amountIn
    ) OverlayMarket(
        "https://metadata.overlay.exchange/mirin/{id}.json",
        _ovl,
        _updatePeriod,
        _leverageMax,
        _oiCap,
        _fundingKNumerator,
        _fundingKDenominator
    ) {
        mirinPool = _mirinPool;
        isPrice0 = _isPrice0;
        windowSize = _windowSize;
        amountIn = _amountIn;
    }

    // SEE: https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/examples/ExampleSlidingWindowOracle.sol#L93
    function computeAmountOut(
        uint256 _priceCumulativeStart,
        uint256 _priceCumulativeEnd,
        uint256 _timeElapsed,
        uint256 _amountIn
    ) private pure returns (uint256 amountOut) {
        // overflow is desired.
        FixedPoint.uq112x112 memory priceAverage =
            FixedPoint.uq112x112(uint224((_priceCumulativeEnd - _priceCumulativeStart) / _timeElapsed));
        amountOut = priceAverage.mul(_amountIn).decode144();
    }

    function lastPrice() public view returns (uint256) {
        uint256 len = IMirinOracle(mirinPool).pricePointsLength();
        require(len > windowSize, "OverlayV1: !MirinInitialized");
        (
            uint256 timestampEnd,
            uint256 price0CumulativeEnd,
            uint256 price1CumulativeEnd
        ) = IMirinOracle(mirinPool).pricePoints(len-1);
        (
            uint256 timestampStart,
            uint256 price0CumulativeStart,
            uint256 price1CumulativeStart
        ) = IMirinOracle(mirinPool).pricePoints(len-1-windowSize);

        if (isPrice0) {
            return computeAmountOut(
                price0CumulativeStart,
                price0CumulativeEnd,
                timestampEnd - timestampStart,
                amountIn
            );
        } else {
            return computeAmountOut(
                price1CumulativeStart,
                price1CumulativeEnd,
                timestampEnd - timestampStart,
                amountIn
            );
        }
    }

    /// @dev Override for Mirin market feed to compute and set TWAP for latest price point index
    function fetchPricePoint() internal virtual override returns (bool success) {
        uint256 price = lastPrice();
        setPricePointLast(price);
        return true;
    }
}
