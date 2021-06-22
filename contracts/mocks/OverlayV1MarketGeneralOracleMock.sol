// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../libraries/FixedPoint.sol";
import "../market/OverlayV1Market.sol";

contract OverlayV1MockMarket is OverlayV1Market {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;

    uint priceIx;
    uint[] public price0s;
    uint[] public price1s;

    bool public immutable isPrice0;

    constructor(
        address _ovl,
        bool _isPrice0,
        uint[] memory _price0s,
        uint[] memory _price1s,
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
        includePrices(_price0s, _price1s);

    }

    function includePrices (
        uint[] memory _price0s,
        uint[] memory _price1s
    ) public {
        price0s = _price0s;
        price1s = _price1s;
    }

    /// @dev Override for mock market feed to feed price to contract
    function fetchPricePoint() internal virtual override returns (bool success) {

        setPricePointCurrent(isPrice0 
            ? price0s[priceIx++] 
            : price1s[priceIx++]
        );

        return true;

    }

}
