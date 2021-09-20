// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IOverlayToken.sol";

interface IOverlayV1Mothership {

    function isMarket(
        address
    ) external view returns (
        bool
    );

    function ovl () external view returns (
        IOverlayToken ovl_
    );

    function allMarkets(
        uint marketIndex
    ) external view returns (
        address marketAddress
    );

    function totalMarkets () external view returns (
            uint
    );

    function getGlobalParams() external view returns (
        uint16 fee_, 
        uint16 feeBurnRate_, 
        uint16 feeUpdateRewardsRate_, 
        address feeTo_, 
        uint8 marginMaintenance_, 
        uint8 marginBurnRate_
    );

    function getUpdateParams() external view returns (
        uint16 feeBurnRate_, 
        uint16 feeUpdateRewardsRate_, 
        uint16 marginBurnRate_,
        address feeTo_
    );

    function getMarginParams() external view returns (
        uint marginMaintenance_, 
        uint marginRewardRate_
    );

    function fee() external view returns (uint256);

    function updateMarket(
        address _market, 
        address _rewardsTo
    ) external;

    function massUpdateMarkets(
        address _rewardsTo
    ) external;

    function hasRole(
        bytes32 _role, 
        address _account
    ) external view returns (
        bool
    );

}
