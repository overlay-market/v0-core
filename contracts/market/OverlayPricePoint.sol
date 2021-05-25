// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

contract OverlayPricePoint {
    // current index pointer for the upcoming price fetch on update
    uint256 public pricePointCurrentIndex;
    // mapping from price point index to realized historical prices
    mapping(uint256 => uint256) public pricePoints;

    constructor() {
        // set to 1 given update window T+1 settlement logic on build
        pricePointCurrentIndex = 1;
    }

    /// @notice Allows inheriting contracts to add the latest realized price
    function setPricePointCurrent(uint256 price) internal {
        pricePoints[pricePointCurrentIndex] = price;
    }

    /// @notice Whether price has been realized for given index
    function hasPricePoint(uint256 pricePointIndex) internal returns (bool) {
        return pricePoints[pricePointIndex] > 0;
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
        pricePointCurrentIndex++;
    }
}
