// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IOverlayV1Factory {

    function isMarket(
        address
    ) external view returns (
        bool
    );

    function getGlobalParams() external view returns (
        uint16 fee, 
        uint16 feeBurnRate, 
        uint16 feeUpdateRewardsRate, 
        address feeTo, 
        uint8 marginMaintenance, 
        uint8 marginBurnRate, 
        address marginTo
    );

    function getFeeParams() external view returns (
        uint16 fee, 
        uint16 feeBurnRate, 
        uint16 feeUpdateRewardsRate, 
        address feeTo
    );

    function getMarginParams() external view returns (
        uint8 marginMaintenance, 
        uint8 marginBurnRate, 
        address marginTo
    );

    function fee() external view returns (uint256);

    function updateMarket(
        address market, 
        address rewardsTo
    ) external;

    function massUpdateMarkets(
        address rewardsTo
    ) external;
}
