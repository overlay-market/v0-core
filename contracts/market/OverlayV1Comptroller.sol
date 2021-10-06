// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../libraries/FixedPoint.sol";

import "./OverlayV1Governance.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract OverlayV1Comptroller {

    // event log(string k, uint v);

    using FixedPoint for uint256;

    uint256 private constant INVERSE_E = 0x51AF86713316A9A;
    uint256 private constant ONE = 1e18;

    // length of roller arrays when we circle
    uint256 constant CHORD = 60; 

    // current element for new rolls
    uint256 public impactCycloid;
    uint256 public brrrrdCycloid;

    Roller[60] public impactRollers;
    Roller[60] public brrrrdRollers;

    struct Roller {
        uint time;
        uint ying;
        uint yang;
    }

    struct ImpactRoller {
        uint time;
        uint lPressure;
        uint sPressure;
    }

    struct BrrrrRoller {
        uint time;
        uint brrr;
        uint anti;
    }

    uint256 internal staticCap;
    uint256 public impactWindow;
    uint256 public lmbda;

    uint256[2] public brrrrdAccumulatooor;
    uint256 constant brrrrdWindowMicro = 1 days;
    uint256 public brrrrdWindowMacro;
    uint256 public brrrrdWhen;
    uint256 public brrrrdExpected;
    uint256 public brrrrdFiling;


    constructor () {

        impactRollers[0] = Roller({
            time: block.timestamp,
            ying: 0,
            yang: 0
        });

        brrrrdRollers[0] = Roller({
            time: block.timestamp,
            ying: 0,
            yang: 0
        });

        brrrrdWhen = block.timestamp;

    }

    function depth () internal virtual view returns ( uint256 depth_ );

    function brrrr (
        uint _brrrr,
        uint _antiBrrrr
    ) internal { 

        uint _now = block.timestamp;
        uint _brrrrdFiling = brrrrdFiling;

        if ( _now > _brrrrdFiling ) { // time to roll in the brrrrr

            uint _brrrrdCycloid = brrrrdCycloid;

            Roller memory _roller = brrrrdRollers[_brrrrdCycloid];

            uint _lastMoment = _roller.time;

            _roller.time = _brrrrdFiling;
            _roller.ying += _brrrr;
            _roller.yang += _brrrr;

            brrrrdCycloid = roll(brrrrdRollers, _roller, _lastMoment, _brrrrdCycloid);

            brrrrdAccumulatooor[0] = _brrrr;
            brrrrdAccumulatooor[1] = _antiBrrrr;

            uint _brrrrdWindowMicro = brrrrdWindowMicro;

            brrrrdFiling += ( ( _now - _brrrrdFiling ) / _brrrrdWindowMicro ) * _brrrrdWindowMicro;

        } else { // add to the brrrr accumulator

            brrrrdAccumulatooor[0] += _brrrr;
            brrrrdAccumulatooor[1] += _antiBrrrr;

        }

    }

    function getBrrrrd () internal view returns (
        int brrrrd_,
        uint now_
    ) { }

    function oiCap () public view returns (
        uint cap_,
        uint now_,
        int brrrrd_
    ) {

        ( brrrrd_, now_ ) = getBrrrrd();

        cap_ = brrrrd_ < 0
            ? Math.min(staticCap, depth())
            : Math.min(staticCap - uint(brrrrd_), depth());

    }

    function intake (
        bool _isLong,
        uint _oi
    ) internal returns (
        uint impact_,
        uint cap_
    ) {

        (   Roller memory _rollerImpact,
            uint _lastMoment,
            uint _impact,
            uint _cap,
            uint _now,
            int _brrrrd ) = _intake(_isLong, _oi);

        brrrrdWhen = _now;

        roll(
            brrrrdRollers,
            _rollerImpact, 
            _lastMoment,
            impactCycloid
        );

        impact_ = _oi.mulUp(_impact);

        brrrr( 0, impact_ );

        cap_ = _cap;

    }

    function _intake (
        bool _isLong,
        uint _oi
    ) internal view returns (
        Roller memory rollerNow_,
        uint lastMoment_,
        uint impact_,
        uint cap_,
        uint now_,
        int brrrrd_
    ) {

        (   uint _lastMoment,
            Roller memory _rollerNow,
            Roller memory _rollerImpact ) = scry(
                impactRollers, 
                impactCycloid, 
                impactWindow );

        ( cap_, now_, brrrrd_ ) = oiCap();

        uint _pressure = _oi.divDown(cap_);

        if (_isLong) _rollerNow.ying += _pressure;
        else _rollerNow.yang += _pressure;

        uint _power = lmbda.mulDown(_isLong
            ? _rollerNow.ying - _rollerImpact.ying
            : _rollerNow.yang - _rollerImpact.yang
        );

        lastMoment_ = _lastMoment;
        rollerNow_ = _rollerNow;
        impact_ = _pressure != 0
            ? ONE.sub(INVERSE_E.powUp(_power))
            : 0;

    }


    function roll (
        Roller[60] storage rollers,
        Roller memory _roller,
        uint _lastMoment,
        uint _cycloid
    ) internal returns (
        uint cycloid_
    ) {

        if (_roller.time != _lastMoment) {

            _cycloid += 1;

            if (_cycloid < CHORD) {

                rollers[_cycloid] = _roller;

            } else {

                _cycloid = 0;

                rollers[_cycloid] = _roller;

            }


        } else {

            rollers[_cycloid] = _roller;

        }

        cycloid_ = _cycloid;

    }

    function scry (
        Roller[60] storage rollers,
        uint _cycloid,
        uint _ago
    ) internal view returns (
        uint lastMoment_,
        Roller memory rollerNow_,
        Roller memory rollerThen_
    ) {

        uint _time = block.timestamp;

        rollerNow_ = rollers[_cycloid];

        lastMoment_ = rollerNow_.time;

        uint _target = _time - _ago;

        if (rollerNow_.time <= _target) {

            rollerNow_.time = _time;
            rollerThen_.ying = rollerNow_.ying;
            rollerThen_.yang = rollerNow_.yang;

            return ( lastMoment_, rollerNow_, rollerThen_ );

        } else if (_time != rollerNow_.time) {

            rollerNow_.time = _time;

        }

        (   Roller memory _beforeOrAt,
            Roller memory _atOrAfter ) = scryRollers(rollers, _cycloid, _target);

        if (_beforeOrAt.time == _target) {

            rollerThen_ = _beforeOrAt;

        } else if (_target == _atOrAfter.time) {

            rollerThen_ = _atOrAfter;

        } else if (_atOrAfter.time == _beforeOrAt.time) {

            rollerThen_ = _beforeOrAt;

        } else {

            uint _yingDiff = _atOrAfter.ying - _beforeOrAt.ying;
            uint _yangDiff = _atOrAfter.yang - _beforeOrAt.yang;

            uint _timeDiff = ( _atOrAfter.time - _beforeOrAt.time ) * 1e18;

            uint _targetRatio = ( ( _target - _beforeOrAt.time ) * 1e18 ).divUp(_timeDiff);

            rollerThen_.ying = _beforeOrAt.ying.add(_yingDiff.mulDown(_targetRatio));
            rollerThen_.yang = _beforeOrAt.yang.add(_yangDiff.mulDown(_targetRatio));
            rollerThen_.time = _target;

        }

    }

    function scryRollers (
        Roller[60] storage rollers,
        uint _cycloid,
        uint _target
    ) internal view returns (
        Roller memory beforeOrAt_,
        Roller memory atOrAfter_
    ) {

        beforeOrAt_ = rollers[_cycloid];

        // if the target is at or after the newest roller, we can return early
        if (beforeOrAt_.time <= _target) {

            if (beforeOrAt_.time == _target) {

                // if newest roller equals target, we're in the same block, so we can ignore atOrAfter
                return ( beforeOrAt_, atOrAfter_ );

            } else {

                atOrAfter_.time = block.timestamp;
                atOrAfter_.ying = beforeOrAt_.ying;
                atOrAfter_.yang = beforeOrAt_.yang;

                return ( beforeOrAt_, atOrAfter_ );

            }
        }

        // now, set before to the oldest roller
        _cycloid = ( _cycloid + 1 ) % CHORD;

        beforeOrAt_ = rollers[_cycloid];

        if ( beforeOrAt_.time <= 1 ) {

            beforeOrAt_ = rollers[0];

        }

        if (_target <= beforeOrAt_.time) return ( beforeOrAt_, beforeOrAt_ );
        else return binarySearch(
            rollers,
            uint32(_target),
            uint16(_cycloid)
        );

    }

    function binarySearch(
        Roller[60] storage self,
        uint32 _target,
        uint16 _cycloid
    ) private view returns (
        Roller memory beforeOrAt_,
        Roller memory atOrAfter_
    ) {

        uint256 l = (_cycloid + 1) % CHORD; // oldest print
        uint256 r = l + CHORD - 1; // newest print
        uint256 i;
        while (true) {
            i = (l + r) / 2;

            beforeOrAt_ = self[i % CHORD];

            // we've landed on an uninitialized roller, keep searching
            if (beforeOrAt_.time <= 1) { l = i + 1; continue; }

            atOrAfter_ = self[(i + 1) % _cycloid];

            bool _targetAtOrAfter = beforeOrAt_.time <= _target;

            if (_targetAtOrAfter && _target <= atOrAfter_.time) break;

            if (!_targetAtOrAfter) r = i - 1;
            else l = i + 1;
        }
    }

}
