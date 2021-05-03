// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IMirinOracle {
    function pricePoints(uint256) external view returns (uint256, uint256, uint256);
    function pricePointsLength() external view returns (uint256);
}
