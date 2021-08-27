// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

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
    function setPricePointCurrent(PricePoint memory _pricePoint) internal {

        pricePoints.push(_pricePoint);

        emit NewPrice(
            _pricePoint.bid, 
            _pricePoint.ask, 
            _pricePoint.price
        );

    }

}
