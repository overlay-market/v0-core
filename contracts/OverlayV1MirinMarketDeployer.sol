// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IMirinFactory.sol";
import "./interfaces/IMirinOracle.sol";

import "./OverlayV1MirinMarket.sol";

contract OverlayV1MirinMarketDeployer {

    // ovl erc20 token
    address public immutable ovl;
    // mirin pool factory
    address public immutable mirinFactory;

    constructor(
        address _ovl,
        address _mirinFactory
    ) {

        // immutables
        ovl = _ovl;
        mirinFactory = _mirinFactory;

    }

    /// @notice Creates a new market contract for given mirin pool address
    function deployMarket(
        address mirinPool,
        bool isPrice0,
        uint256 updatePeriod,
        uint256 windowSize,
        uint8 leverageMax,
        uint16 marginAdjustment,
        uint144 oiCap,
        uint112 fundingKNumerator,
        uint112 fundingKDenominator,
        uint256 amountIn
    ) external returns (OverlayV1MirinMarket marketContract) {

        require(IMirinFactory(mirinFactory).isPool(mirinPool), "OverlayV1: !MirinPool");
        require(IMirinOracle(mirinPool).pricePointsLength() > 1, "OverlayV1: !MirinInitialized");

        marketContract = new OverlayV1MirinMarket(
            ovl,
            mirinPool,
            isPrice0,
            updatePeriod,
            windowSize,
            leverageMax,
            marginAdjustment,
            oiCap,
            fundingKNumerator,
            fundingKDenominator,
            amountIn
        );

    }

}