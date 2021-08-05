// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../libraries/Position.sol";

interface IOverlayV1Market is IERC1155 {

    event CoreUpdate(uint256 price, int256 fundingPaid);

    function ovl() external view returns (address);
    function factory() external view returns (address);

    function feed() external view returns (address);
    function windowSize() external view returns (uint256);
    function updatePeriod() external view returns (uint256);
    function updateBlockLast() external view returns (uint256);
    function leverageMax() external view returns (uint8);
    function fundingKNumerator() external view returns (uint256);
    function fundingKDenominator() external view returns (uint256);

    function queuedOiLong() external view returns (uint256);
    function queuedOiShort() external view returns (uint256);
    function oiLong() external view returns (uint256);
    function oiShort() external view returns (uint256);
    function oiCap() external view returns (uint256);

    function pricePointCurrentIndex() external view returns (uint256);
    function pricePoints(uint256 index) external view returns (uint256 price );

    function MAX_FUNDING_COMPOUND() external view returns (uint16);

    function addCollateral (
        address _collateral
    ) external;

    function entryData (
        bool _isLong
    ) external view returns (
        uint256 freeOi_,
        uint256 maxLev_,
        uint256 pricePoint_,
        uint256 t1Compounding_
    );

    function enterOI(
        bool _isLong,
        uint _oi
    ) external;

    function exitData (
        bool _isLong,
        uint256 _pricePoint
    ) external view returns (
        uint oi_,
        uint oiShares_,
        uint priceFrame_,
        uint tCompounding_
    );

    function exitOI(
        bool _compounded,
        bool _isLong,
        uint _oi,
        uint _oiShares
    ) external;

    function adjustParams(
        uint256 _updatePeriod, 
        uint256 _compoundingPeriod, 
        uint144 _oiCap, 
        uint112 _fundingKNumerator, 
        uint112 _fundingKDenominator,
        uint8 _leverageMax
    ) external;

    function data(
        bool _isLong
    ) external view returns (
        uint256 oi,
        uint256 oiShares,
        uint256 freeOi,
        uint256 maxLev,
        uint256 currentPricePoint
    );

    function update () external returns (bool updated);

}
