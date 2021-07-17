// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./interfaces/IUniV3Factory.sol";
import "./market/OverlayV1Factory.sol";
import "./OverlayV1UniswapV3Deployer.sol";

contract OverlayV1UniswapV3Factory is OverlayV1Factory {

    address public immutable deployer;
    address public immutable uniV3Factory;

    constructor(
        address _ovl,
        address _deployer,
        address _uniV3Factory,
        uint16 _fee,
        uint16 _feeBurnRate,
        uint16 _feeUpdateRewardsRate,
        address _feeTo,
        uint16 _marginMaintenance,
        uint16 _marginBurnRate,
        uint16 _marginRewardRate
    ) OverlayV1Factory (
        _ovl,
        _fee,
        _feeBurnRate,
        _feeUpdateRewardsRate,
        _feeTo,
        _marginMaintenance,
        _marginBurnRate,
        _marginRewardRate
    ) {
    
        // immutables
        deployer = _deployer;
        uniV3Factory = _uniV3Factory;

    }

    /// @notice Creates a new market contract for given uniV3 pool address
    function createMarket(
        address uniV3Pool,
        uint256 updatePeriod,
        uint8 leverageMax,
        uint16 marginAdjustment,
        uint144 oiCap,
        uint112 fundingKNumerator,
        uint112 fundingKDenominator,
        bool isPrice0,
        uint256 windowSize,
        uint256 amountIn
    ) external onlyOwner returns (OverlayV1UniswapV3Market marketContract) {
        // require(IMirinFactory(uniV3Factory).isPool(uniV3Pool), "OverlayV1: !MirinPool");

        (bool success, bytes memory result) = deployer.delegatecall(
            abi.encodeWithSignature("deployMarket(address,address,uint256,uint8,uint16,uint144,uint112,uint112,bool,uint256,uint256)",
            ovl,
            uniV3Pool,
            updatePeriod,
            leverageMax,
            marginAdjustment,
            oiCap,
            fundingKNumerator,
            fundingKDenominator,
            isPrice0,
            windowSize,
            amountIn
        ));
        
        marketContract = abi.decode(result, (OverlayV1UniswapV3Market));

        initializeMarket(address(marketContract));

        emit MarketDeployed(address(marketContract), uniV3Pool, isPrice0);
        
    }
}
