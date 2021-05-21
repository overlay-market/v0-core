// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./libraries/FixedPoint.sol";
import "./interfaces/IMirinOracle.sol";

import "./OverlayMarket.sol";
import "./OverlayToken.sol";

contract OverlayMirinMarket is OverlayMarket {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;

    address public immutable mirinPool;
    bool public immutable isPrice0;
    // window size for sliding window TWAP calc => TODO: don't make immutable?
    uint256 public immutable windowSize;

    constructor(
        address _ovl,
        address _mirinPool,
        bool _isPrice0,
        uint256 _updatePeriod,
        uint256 _windowSize,
        uint8 _leverageMax,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator
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
    }

    // SEE: https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/examples/ExampleSlidingWindowOracle.sol#L93
    function computeAmountOut(
        uint256 priceCumulativeStart,
        uint256 priceCumulativeEnd,
        uint256 timeElapsed,
        uint256 amountIn
    ) private pure returns (uint256 amountOut) {
        // overflow is desired.
        FixedPoint.uq112x112 memory priceAverage =
            FixedPoint.uq112x112(uint224((priceCumulativeEnd - priceCumulativeStart) / timeElapsed));
        amountOut = priceAverage.mul(amountIn).decode144();
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
                0 // TODO: Fix w decimals
            );
        } else {
            return computeAmountOut(
                price1CumulativeStart,
                price1CumulativeEnd,
                timestampEnd - timestampStart,
                0 // TODO: Fix w decimals
            );
        }
    }

    /// @notice Updates funding payments, price observatiosn, and cumulative fees
    /// @dev Override for Mirin market feed to also update oracle prices
    function update(address rewardsTo) public virtual override {
        uint256 blockNumber = block.number;
        uint256 elapsed = (blockNumber - updateBlockLast) / updatePeriod;
        if (elapsed > 0) {
            // TODO: update price feed ...
            super.update(rewardsTo);
        }
    }
}
