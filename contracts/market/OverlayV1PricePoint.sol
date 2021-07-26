// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

abstract contract OverlayV1PricePoint {

    // mapping from price point index to realized historical prices
    uint[] public pricePoints;

    constructor () {

        pricePoints.push(0);

    }

    /// @notice Get the current price point index
    function pricePointCurrentIndex() external view returns (uint) {

        return pricePoints.length;

    }

    /// @notice Allows inheriting contracts to add the latest realized price
    function setPricePointCurrent(uint256 price) internal {
        pricePoints.push(price);
    }

    // TODO: collapse updatePricePoints and fetchPricePoints into one function 
    // where inherited function uses super. Check that SOLC 0.8.2 still uses
    // super as such.

    /// @notice Fetches last price from oracle and sets in pricePoints
    /// @dev Override for each specific market feed to also fetch from oracle value for T+1
    function fetchPricePoint() internal virtual returns (uint256 price);

    /// @notice Forwards price point index for next update period
    /// @dev Override fetchPricePoint for each specific market feed
    function updatePricePoints(
        uint _updatePeriod,
        uint _updateLast
    ) internal returns (uint256) {

        // we need to settle a prior price 
        // potentially far after the fact
        
        // we need to get the current price on unwinding

        // on build we need to settle prior price

        // on unwind we need to settle prior price
        // and if that price is not the unwind price
        // then we need to get the unwind price

        // so we need to know when an update shall be committed 

        // so if we build then we know the next eligible update 
        // is at the update period plus the last eligible update time

        // at deployment the beginning is set to the block time

        // we use this to draw update epoch times

        // updateEpoch

        // at build we record the next update time - queuedUpdate 

        // at unwind we read the queuedUpdate 
        // we see if that is also the just past period
        // if so we update one price 
        // if not we update two prices
        // we set the queuedUpdate to an ignore value
        // signifying future unwinds only need to get the
        // just past period

        return fetchPricePoint();
    }
}
