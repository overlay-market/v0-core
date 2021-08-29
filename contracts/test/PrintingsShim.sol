// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../market/OverlayV1OI.sol";

contract PrintingShim is OverlayV1OI {
    constructor (
        uint _printWindow, 
        uint _impactWindow
    ) OverlayV1OI(
        _printWindow,
        _impactWindow
    ) { }

}