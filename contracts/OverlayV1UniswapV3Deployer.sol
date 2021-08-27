// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./OverlayV1UniswapV3Market.sol";

contract OverlayV1UniswapV3Deployer {

    /// @notice Creates a new market contract for given mirin pool address
    function deployMarket(
        address ovl,
        address uniPool,
        uint256 updatePeriod,
        uint256 compoundPeriod,
        uint256 printWindow,
        uint256 macroWindow,
        uint256 microWindow,
        uint144 oiCap,
        uint112 fundingK,
        uint8   leverageMax,
        uint128 amountIn,
        bool    isPrice0
    ) external returns (OverlayV1UniswapV3Market marketContract) {
        marketContract = new OverlayV1UniswapV3Market(
            ovl,
            uniPool,
            updatePeriod,
            compoundPeriod,
            printWindow,
            macroWindow,
            microWindow,
            oiCap,
            fundingK,
            leverageMax,
            amountIn,
            isPrice0
        );
    }

}
