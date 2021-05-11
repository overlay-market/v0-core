// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IOVLMarket {
    function ovl() external view returns (address);
    function factory() external view returns (address);
    function leverageMax() external view returns (uint256);
    function cap() external view returns (uint256);
    function fundingD() external view returns (uint256);
    function updateBlockLast() external view returns (uint256);
    function uri(uint256) external view returns (string memory);
    function updatable() external view returns (bool);
    function update(address) external;
    function build(uint256, bool, uint256, address) external;
    function unwind(uint256, uint256, address) external;
}
