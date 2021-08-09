// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

abstract contract OverlayV1PricePoint {

    // mapping from price point index to realized historical prices
    uint[] public pricePoints;

    event NewPrice(uint _price);

    /// @notice Get the current price point index
    function pricePointCurrentIndex() external view returns (uint) {

        return pricePoints.length;

    }

    /// @notice Allows inheriting contracts to add the latest realized price
    function setPricePointCurrent(uint256 price) internal {
        pricePoints.push(price);
        emit NewPrice(price);
    }

}
