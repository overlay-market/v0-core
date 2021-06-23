// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../libraries/FixedPoint.sol";
import "../market/OverlayV1Market.sol";

contract OverlayV1MarketGeneralOracleMock is OverlayV1Market {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;

    uint priceIx;
    uint[] public prices;

    bool public immutable isPrice0;

    constructor(
        address _ovl,
        bool _isPrice0,
        uint[] memory _prices,
        uint256 _updatePeriod,
        uint8 _leverageMax,
        uint16 _marginAdjustment,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator
    ) OverlayV1Market(
        "https://metadata.overlay.exchange/v1/mirin/{id}.json",
        _ovl,
        _updatePeriod,
        _leverageMax,
        _marginAdjustment,
        _oiCap,
        _fundingKNumerator,
        _fundingKDenominator
    ) {

        isPrice0 = _isPrice0;
        includePrices(_prices);

    }

    function test () public pure returns (string memory) {
        string memory hello = "hello";
        return hello;
    }

    function includePrices (
        uint[] memory _prices
    ) public { 
        prices = _prices; 
    }

    /// @dev Override for mock market feed to feed price to contract
    function fetchPricePoint() internal virtual override returns (bool success) {

        setPricePointCurrent(prices[priceIx++]);
        return true;

    }

}
