// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../market/OverlayV1Comptroller.sol";

contract ComptrollerShim is OverlayV1Comptroller {

    constructor (
        uint _impactWindow,
        uint _lmbda,
        uint _staticCap,
        uint _brrrrdExpected,
        uint _brrrrdWindowMacro,
        uint _brrrrdWindowMicro
    ) {

        impactWindow = _impactWindow;
        lmbda = _lmbda;
        staticCap = _staticCap;
        brrrrdExpected = _brrrrdExpected;
        brrrrdWindowMacro = _brrrrdWindowMacro;
        brrrrdWindowMicro = _brrrrdWindowMicro;

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

        impactRollers[index].time = __timestamp;
        impactRollers[index].ying = __longPressure;
        impactRollers[index].yang = __shortPressure;

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
            rollerThen_ ) = scry(impactRollers, impactCycloid, _ago);


    }

    function brrrrBatch (
        uint[] memory _brrrr,
        uint[] memory _antiBrrrr
    ) public {

        uint len = _brrrr.length;

        for (uint i = 0; i < len; i++) {

            brrrr( _brrrr[i], _antiBrrrr[i] );

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

        }

    }

    function viewImpact (
        bool _isLong,
        uint _oi
    ) public view returns (
        uint impact_
    ) {

        ( ,,impact_, ) = _intake(_isLong, _oi);

    }

}