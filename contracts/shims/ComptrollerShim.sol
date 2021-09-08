// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../market/OverlayV1Comptroller.sol";

contract ComptrollerShim is OverlayV1Comptroller {

    constructor (
        uint impactWindow,
        uint brrrrWindow,
        uint _lambda
    ) OverlayV1Comptroller (
        impactWindow,
        brrrrWindow
    ) {
        lambda = _lambda;
    }

    function setRoller (
        uint index,
        uint __timestamp,
        uint __brrrr,
        uint __longPressure,
        uint __shortPressure
    ) public {

        rollers[index].time = __timestamp;
        rollers[index].brrrr = __brrrr;
        rollers[index].longPressure = __longPressure;
        rollers[index].shortPressure = __shortPressure;

    }

    function brrrr (
        uint[] memory __brrrr
    ) public returns (
        uint brrrr_ 
    ) {

        uint len = __brrrr.length;

        for (uint i = 0; i < len; i++) {

            brrrr_ = noteBrrrr(__brrrr[i]);

        }

    }

    function viewBrrrr (
        uint __brrrr
    ) public view returns (
        uint brrrr_
    ) {

        ( ,,brrrr_ ) = _brrrr(__brrrr);

    }

    function impact (
        bool[] memory _isLong,
        uint[] memory _oi
    ) public returns (
        uint impact_
    ) {

        uint len = _isLong.length;


        for (uint i = 0; i < len; i++) {

            ( impact_, ) = intake(_isLong[i], _oi[i]);

            emit log("impact_", impact_);

        }

        emit log("now", block.timestamp);
        emit log("block number", block.number);

    }

    function viewImpact (
        bool _isLong,
        uint _oi
    ) public view returns (
        uint impact_
    ) {

        ( ,,impact_, ) = _intake(_isLong, _oi);

    }

    function overflow (
        uint a,
        uint b
    ) public pure returns (
        uint c
    ) {
        unchecked {
            c = a + b;
        }
    }
    function underflow (
        uint a,
        uint b
    ) public pure returns (
        uint c
    ) {
        unchecked {
            c = a - b;
        }
    }
    
}