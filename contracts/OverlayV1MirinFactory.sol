// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./interfaces/IMirinFactory.sol";
import "./market/OverlayV1Factory.sol";
import "./OverlayV1MirinDeployer.sol";

contract OverlayV1MirinFactory is OverlayV1Factory {

    address public immutable deployer;
    address public immutable mirinFactory;

    constructor(
        address _ovl,
        uint16 _fee,
        uint16 _feeBurnRate,
        uint16 _feeUpdateRewardsRate,
        address _feeTo,
        uint16 _marginMaintenance,
        uint16 _marginBurnRate,
        address _marginTo,
        address _mirinFactory,
        address _deployer
    ) OverlayV1Factory(
        _ovl,
        _fee,
        _feeBurnRate,
        _feeUpdateRewardsRate,
        _feeTo,
        _marginMaintenance,
        _marginBurnRate,
        _marginTo
    ) {
        // immutables
        mirinFactory = _mirinFactory;
        deployer = _deployer;
    }

    /// @notice Creates a new market contract for given mirin pool address
    function createMarket(
        address mirinPool,
        uint256 updatePeriod,
        uint8 leverageMax,
        uint16 marginAdjustment,
        uint144 oiCap,
        uint112 fundingKNumerator,
        uint112 fundingKDenominator,
        bool isPrice0,
        uint256 windowSize,
        uint256 amountIn
    ) external onlyOwner returns (OverlayV1MirinMarket marketContract) {
        require(IMirinFactory(mirinFactory).isPool(mirinPool), "OverlayV1: !MirinPool");

        (bool success, bytes memory result) = deployer.delegatecall(
            abi.encodeWithSignature("deployMarket(address,bool,uint256,uint256,uint8,uint16,uint144,uint112,uint112,uint256)",
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
        ));
        marketContract = abi.decode(result, (OverlayV1MirinMarket));

        initializeMarket(address(marketContract));
    }
}
