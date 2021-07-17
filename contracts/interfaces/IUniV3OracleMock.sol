// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IUniswapV3OracleMock {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function window() external view returns (uint);
    function observations(uint256) external view returns (int56[] memory);
    function observationsLength() external view returns (uint);
    function addObservations(int56[][] calldata) external;
    function observe(uint32[] calldata) external view returns (int56[] memory, uint160[] memory);
}
