// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

abstract contract OverlayV1PricePoint {

    struct PricePoint {
        uint256 bid;
        uint256 ask;
        uint256 price;
    }

    // mapping from price point index to realized historical prices
    PricePoint[] public pricePoints;

    event NewPrice(uint bid, uint ask, uint price);

    /// @notice Get the current price point index
    function pricePointCurrentIndex() external view returns (uint) {

        return pricePoints.length;

    }

    /// @notice Allows inheriting contracts to add the latest realized price
    function setPricePointCurrent(uint256 bid, uint256 ask, uint256 price) internal {

        pricePoints.push(PricePoint( bid, ask, price));

        emit NewPrice(bid, ask, price);

    }

}
