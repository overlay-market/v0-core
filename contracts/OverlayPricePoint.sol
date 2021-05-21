// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "./libraries/FixedPoint.sol";
import "./libraries/Position.sol";
import "./interfaces/IOverlayFactory.sol";

import "./OverlayToken.sol";

contract OverlayPricePoint {
    // last pointer set for price fetches
    uint256 public pricePointLastIndex;
    // mapping from price point index to realized historical prices
    mapping(uint256 => uint256) public pricePoints;

    /// @notice Allows inheriting contracts to add the latest realized price
    function setPricePointLast(uint256 price) internal {
        pricePoints[pricePointLastIndex] = price;
    }

    /// @notice Fetches last price from oracle and sets in pricePoints
    /// @dev Override for each specific market feed to also fetch from oracle value at T
    function fetchPricePoint() internal virtual returns (bool success) {
        return true;
    }

    /// @notice Forwards price point index for next update period
    /// @dev Override fetchPricePoint for each specific market feed
    function updatePricePoints() internal {
        fetchPricePoint();
        pricePointLastIndex++;
    }
}
