// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../market/OverlayV1Comptroller.sol";

contract ComptrollerShim is OverlayV1Comptroller {

    constructor (
        uint _staticCap,
        uint _impactWindow,
        uint _brrrrFade,
        uint _lambda
    ) {
        staticCap = _staticCap;
        impactWindow = _impactWindow;
        brrrrFade = _brrrrFade;
        lambda = _lambda;
    }

    function depth () internal view override returns (uint256) {

        return staticCap;

    }

    function setRoller (
        uint index,
        uint __timestamp,
        uint __longPressure,
        uint __shortPressure
    ) public {

        rollers[index].time = __timestamp;
        rollers[index].longPressure = __longPressure;
        rollers[index].shortPressure = __shortPressure;

    }

    function viewScry(
        uint _ago
    ) public view returns (
        Roller memory rollerNow_,
        Roller memory rollerThen_
    ) {

        uint lastMoment;

        (   lastMoment,
            rollerNow_,
            rollerThen_ ) = scry(_ago);

        // emit log("rollerNow_.longPressure", rollerNow_.longPressure);
        // emit log("rollerNow_.shortPressure", rollerNow_.shortPressure);

        // emit log("rollerThen_.longPressure", rollerThen_.longPressure);
        // emit log("rollerThen_.shortPressure", rollerThen_.shortPressure);


    }

    function brrrrBatch (
        uint[] memory _brrrr,
        uint[] memory _antiBrrrr
    ) public {

        uint len = _brrrr.length;

        for (uint i = 0; i < len; i++) {

            ( int _brrrrd, uint _now ) = getBrrrrd();

            brrrr(
                _brrrr[i], 
                _antiBrrrr[i], 
                _brrrrd
            );

            brrrrdWhen = _now;

        }

    }

    function impactBatch (
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

        ( ,,impact_,,, ) = _intake(_isLong, _oi);

    }

}