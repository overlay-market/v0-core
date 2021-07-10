// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./OverlayV1UniswapV3Market.sol";

contract OverlayV1UniswapV3Deployer {

    /// @notice Creates a new market contract for given mirin pool address
    function deployMarket(
        address ovl,
        address uniPool,
        uint256 updatePeriod,
        uint8 leverageMax,
        uint16 marginAdjustment,
        uint144 oiCap,
        uint112 fundingKNumerator,
        uint112 fundingKDenominator,
        bool isPrice0,
        uint256 windowSize,
        uint256 amountIn
    ) external returns (OverlayV1UniswapV3Market marketContract) {
        marketContract = new OverlayV1UniswapV3Market(
            ovl,
            uniPool,
            updatePeriod,
            leverageMax,
            marginAdjustment,
            oiCap,
            fundingKNumerator,
            fundingKDenominator,
            isPrice0,
            windowSize,
            amountIn
        );
    }

}
