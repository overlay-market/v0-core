// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../libraries/Position.sol";

interface IOverlayMarket is IERC1155 {
    event Build(address indexed sender, uint256 positionId, uint256 oi, uint256 debt);
    event Unwind(address indexed sender, uint256 positionId, uint256 oi, uint256 debt);
    event Update(address indexed sender, address indexed rewarded, uint256 reward);
    event Liquidate(address indexed sender, address indexed rewarded, uint256 reward);
    function ovl() external view returns (address);
    function factory() external view returns (address);
    function updatePeriod() external view returns (uint256);
    function leverageMax() external view returns (uint8);
    function oiCap() external view returns (uint256);
    function fundingKNumerator() external view returns (uint256);
    function fundingKDenominator() external view returns (uint256);
    function updateBlockLast() external view returns (uint256);
    function MAX_FUNDING_COMPOUND() external view returns (uint16);
    function oiLong() external view returns (uint256);
    function oiShort() external view returns (uint256);
    function positions(uint256) external view returns (Position.Info memory);
    function positionsLength() external view returns (uint256);
    function uri(uint256) external view returns (string memory);
    function updatable() external view returns (bool);
    function update(address) external;
    function build(uint256, bool, uint256, address) external;
    function unwind(uint256, uint256, address) external;
    function liquidatable(uint256) external;
    function liquidate(uint256, address) external;
}
