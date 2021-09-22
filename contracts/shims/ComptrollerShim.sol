// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../market/OverlayV1Comptroller.sol";

contract ComptrollerShim is OverlayV1Comptroller {

    // event log(string k, uint v);

    // constructor (
    //     uint _oiCap,
    //     uint _impactWindow,
    //     uint _brrrrFade,
    //     uint _lambda
    // ) {
    //     oiCap = _oiCap;
    //     lambda = _lambda;
    //     impactWindow = _impactWindow;
    //     brrrrFade = _brrrrFade;
    // }

    function depth () internal view override returns (uint256) {}

    // function setRoller (
    //     uint index,
    //     uint __timestamp,
    //     uint __longPressure,
    //     uint __shortPressure
    // ) public {

    //     rollers[index].time = __timestamp;
    //     rollers[index].longPressure = __longPressure;
    //     rollers[index].shortPressure = __shortPressure;

    // }

    // function viewScry(
    //     uint _ago
    // ) internal view returns (
    //     Roller memory rollerNow_,
    //     Roller memory rollerThen_
    // ) {

    //     uint lastMoment;

    //     (   lastMoment,
    //         rollerNow_,
    //         rollerThen_ ) = scry(_ago);

    // }

    // function brrrr (
    //     int[] memory __brrrr
    // ) public {

    //     uint len = __brrrr.length;

    //     for (uint i = 0; i < len; i++) brrrr(__brrrr[i]);

    // }

    // function impact (
    //     bool[] memory _isLong,
    //     uint[] memory _oi
    // ) public returns (
    //     uint impact_
    // ) {

    //     uint len = _isLong.length;


    //     for (uint i = 0; i < len; i++) {

    //         ( impact_, ) = intake(_isLong[i], _oi[i]);

    //         emit log("impact_", impact_);

    //     }

    //     emit log("now", block.timestamp);
    //     emit log("block number", block.number);

    // }

    // function viewImpact (
    //     bool _isLong,
    //     uint _oi
    // ) public returns (
    //     uint impact_
    // ) {

    //     ( ,,impact_, ) = _intake(_isLong, _oi);

    // }

    // function overflow (
    //     uint a,
    //     uint b
    // ) public pure returns (
    //     uint c
    // ) {
    //     unchecked {
    //         c = a + b;
    //     }
    // }
    // function underflow (
    //     uint a,
    //     uint b
    // ) public pure returns (
    //     uint c
    // ) {
    //     unchecked {
    //         c = a - b;
    //     }
    // }
    
}