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
        uint256 depth;
    }

    uint256 public pbnj;

    uint256 public updated;

    uint256 immutable public priceFrameCap;

    // mapping from price point index to realized historical prices
    PricePoint[] internal _pricePoints;

    event NewPricePoint(uint bid, uint ask, uint depth);

    constructor(
        uint256 _priceFrameCap
    ) {

        require(1e18 <= _priceFrameCap, "OVLV1:!priceFrame");
        priceFrameCap = _priceFrameCap;

    }

    function fetchPricePoint () public view virtual returns (PricePoint memory);

    /// @notice Get the index of the next price to be realized
    /// @dev Returns the index of the _next_ price
    /// @return nextIndex_ The length of the price point array
    function pricePointNextIndex() public view returns (
        uint nextIndex_
    ) {

        nextIndex_ = _pricePoints.length;

    }


    /// @notice All past price points.
    /// @dev Returns the price point if it exists.
    /// @param _pricePointIndex Index of the price point being queried.
    /// @return pricePoint_ Price point, if it exists.
    function pricePoints(
        uint256 _pricePointIndex
    ) external view returns (
        PricePoint memory pricePoint_
    ) {

        uint _len = _pricePoints.length;

        require(_pricePointIndex <  _len ||
               (_pricePointIndex == _len && updated != block.timestamp),
               "OVLV1:!price");

        if (_pricePointIndex == _len) {

            pricePoint_ = fetchPricePoint();

        } else {

            pricePoint_ = _pricePoints[_pricePointIndex];

        }

    }

    /// @notice Inserts the bid/ask spread into the price.
    /// @dev Takes two time weighted average prices from the market feed
    /// and composes them into a price point, which has a bid and an ask.
    /// The ask is the max of the two twaps multiplied by euler's number 
    /// raised to the market's spread. The bid is the min of the twaps
    /// multiplied by the inverse of euler's number raised to the spread.
    /// @param _microPrice The shorter TWAP.
    /// @param _macroPrice The longer TWAP.
    /// @param _depth Time weighted liquidity of market in OVL terms
    /// @return pricePoint_ The price point with bid/ask/index.
    function computePricePoint (
        uint _microPrice,
        uint _macroPrice,
        uint _depth 
    ) internal view returns (
        PricePoint memory pricePoint_
    ) {

        uint _ask = Math.max(_macroPrice, _microPrice).mulUp(E.powUp(pbnj));

        uint _bid = Math.min(_macroPrice, _microPrice).mulDown(INVERSE_E.powUp(pbnj));

        pricePoint_ = PricePoint(
            _bid,
            _ask,
            _depth
        );

    }

    function pricePointCurrent () public view returns (
        PricePoint memory pricePoint_
    ){

        uint _now = block.timestamp;
        uint _updated = updated;

        if (_now != _updated) {

            pricePoint_ = fetchPricePoint();

        } else {

            pricePoint_ = _pricePoints[_pricePoints.length - 1];

        }

    }

    /// @notice Allows inheriting contracts to add the latest realized price
    function setPricePointNext(
        PricePoint memory _pricePoint
    ) internal {

        emit NewPricePoint(
            _pricePoint.bid, 
            _pricePoint.ask, 
            _pricePoint.depth
        );

        _pricePoints.push(_pricePoint);

    }

}
