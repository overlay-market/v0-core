// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "../libraries/FixedPoint.sol";

abstract contract OverlayV1PricePoint {

    using FixedPoint for uint256;

    uint256 private constant E = 0x25B946EBC0B36351;
    uint256 private constant INVERSE_E = 0x51AF86713316A9A;

    struct PricePoint {
        uint256 bid;
        uint256 ask;
        uint256 price;
    }

    uint256 public pbnj;

    // mapping from price point index to realized historical prices
    PricePoint[] internal _pricePoints;

    event NewPrice(uint bid, uint ask, uint price);

    /// @notice Get the current price point index
    function pricePointCurrentIndex() external view returns (uint) {

        return _pricePoints.length;

    }

    function pricePoints(
        uint256 _pricePointIndex
    ) external view returns (
        PricePoint memory pricePoint_
    ) {

        pricePoint_ = _pricePoints[_pricePointIndex];

    }

    function insertSpread (
        uint _microPrice,
        uint _macroPrice
    ) internal view returns (
        PricePoint memory pricePoint_
    ) {

        uint _ask = Math.max(_macroPrice, _microPrice).mulUp(E.powUp(pbnj));

        uint _bid = Math.min(_macroPrice, _microPrice).mulDown(INVERSE_E.powUp(pbnj));

        pricePoint_ = PricePoint(
            _bid,
            _ask,
            _macroPrice
        );

    }

    /// @notice Allows inheriting contracts to add the latest realized price
    function setPricePointCurrent(PricePoint memory _pricePoint) internal {

        _pricePoints.push(_pricePoint);

        emit NewPrice(
            _pricePoint.bid, 
            _pricePoint.ask, 
            _pricePoint.price
        );

    }

}
