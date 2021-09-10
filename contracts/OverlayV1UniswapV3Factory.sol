// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

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
        uint256 compoundingPeriod,
        uint256 printWindow,
        uint256 macroWindow,
        uint256 microWindow,
        uint256 oiCap,
        uint256 fundingK,
        uint256 leverageMax,
        uint256 amountIn,
        bool    isPrice0
    ) external onlyOwner returns (OverlayV1UniswapV3Market marketContract) {

        (  ,bytes memory result) = deployer.delegatecall(
            abi.encodeWithSignature("deployMarket(address,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint128,bool)",
            ovl,
            uniV3Pool,
            updatePeriod,
            compoundingPeriod,
            printWindow,
            macroWindow,
            microWindow,
            oiCap,
            fundingK,
            leverageMax,
            amountIn,
            isPrice0
        ));
        
        marketContract = abi.decode(result, (OverlayV1UniswapV3Market));

        initializeMarket(address(marketContract));

        emit MarketDeployed(address(marketContract), uniV3Pool, isPrice0);
        
    }
}
