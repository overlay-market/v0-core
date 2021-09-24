// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../libraries/FixedPoint.sol";

import "./OverlayV1Governance.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract OverlayV1Comptroller { 

    event log(string k, uint v);

    using FixedPoint for uint256;

    uint256 private constant INVERSE_E = 0x51AF86713316A9A;
    uint256 private constant ONE = 1e18;

    uint24 public index;
    uint24 public cardinality;
    uint24 public cardinalityNext;
    Roller[216000] public rollers;

    struct Roller {
        uint time;
        uint longPressure;
        uint shortPressure;
    }

    uint256 internal staticCap;
    uint256 public impactWindow;
    uint256 public lambda;

    int256 public brrrrd;
    uint256 public brrrrdWhen;
    uint256 public brrrrFade;

    constructor () {

        cardinality = 1;
        cardinalityNext = 1;

        rollers[0] = Roller({
            time: block.timestamp,
            longPressure: 0,
            shortPressure: 0
        });

        brrrrdWhen = block.timestamp;

    }

    function expand (
        uint16 next
    ) public {

        require(cardinalityNext < next, 'OVLV1:next<curr');

        for (uint24 i = cardinalityNext; i < next; i++) rollers[i].time = 1;

        cardinalityNext = next;

    }

    function depth () internal virtual view returns ( uint256 depth_ );

    function getBrrrrd () internal view returns (
        int brrrrd_,
        uint now_
    ) {

        brrrrd_ = brrrrd;

        uint _then = brrrrdWhen;

        now_ = block.timestamp;

        if (_then < now_) {

            uint _fade = ( now_ - _then ).mulUp(brrrrFade);

            0 < brrrrd_
                ? brrrrd_ -= int(Math.min(uint(brrrrd_), _fade))
                : brrrrd_ += int(Math.min(uint(-brrrrd_), _fade));

        }

    }

    function cap () public view returns (
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

        roll(_rollerImpact, _lastMoment);

        impact_ = _oi.mulUp(_impact);

        brrrr(0, _impact, _brrrrd);

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
            Roller memory _rollerImpact ) = scry(impactWindow);
        
        ( cap_, now_, brrrrd_ ) = cap();

        uint _pressure = _oi.divUp(cap_);

        if (_isLong) _rollerNow.longPressure += _pressure;
        else _rollerNow.shortPressure += _pressure;

        uint _power = lambda.mulUp(_isLong
            ? _rollerNow.longPressure - _rollerImpact.longPressure
            : _rollerNow.shortPressure - _rollerImpact.shortPressure
        );

        lastMoment_ = _lastMoment;
        rollerNow_ = _rollerNow;
        impact_ = _pressure != 0 
            ? ONE.sub(INVERSE_E.powUp(_power)) 
            : 0;

    }

    function brrrr (
        uint _brrrr,
        uint _antiBrrrr,
        int _brrrrd
    ) internal {

        if (0 < _brrrr) {

            int _staticCap = int(staticCap);

            // enforce brrrrd < static cap in mt staticCap - b
            _brrrrd = _staticCap < ( _brrrrd += int(_brrrr))
                ? _staticCap
                : _brrrrd;

        } 

        if (0 < _antiBrrrr) {

            _brrrrd -= int(_antiBrrrr);

        }

        brrrrd = _brrrrd;

    }

    function roll (
        Roller memory _roller,
        uint _lastMoment
    ) internal {

        uint24 _index = index;
        uint24 _cardinality = cardinality;
        uint24 _cardinalityNext = cardinalityNext;

        if (_roller.time != _lastMoment) {

            _index += 1;

            if (_index < _cardinality) {

                rollers[_index] = _roller;

            } else if (_cardinality < _cardinalityNext) {

                _cardinality += 1;
                rollers[_index] = _roller;

            } else {

                _index = 0;
                rollers[_index] = _roller;

            }

            index = _index;
            cardinality = _cardinality;

        } else {

            rollers[_index] = _roller;

        }

    }

    function scry (
        uint _ago
    ) internal view returns (
        uint lastMoment_,
        Roller memory rollerNow_, 
        Roller memory rollerThen_
    ) {


        uint _time = block.timestamp;

        rollerNow_ = rollers[index];

        lastMoment_ = rollerNow_.time;

        uint _target = _time - _ago;

        if (rollerNow_.time <= _target) {

            rollerNow_.time = _time;
            rollerThen_.longPressure = rollerNow_.longPressure;
            rollerThen_.shortPressure = rollerNow_.shortPressure;

            return ( lastMoment_, rollerNow_, rollerThen_ );

        } else if (_time != rollerNow_.time) {

            rollerNow_.time = _time;

        }

        (   Roller memory _beforeOrAt, 
            Roller memory _atOrAfter ) = scryRollers(_target);

        if (_atOrAfter.time - _beforeOrAt.time > _ago) {

            rollerThen_.time = _target;

        } else if (_beforeOrAt.time == _target) {

            rollerThen_ = _beforeOrAt;

        } else if (_target == _atOrAfter.time) {

            rollerThen_ = _atOrAfter;

        } else if (_atOrAfter.time == _beforeOrAt.time) {

            rollerThen_ = _beforeOrAt;
        
        } else {

            uint _longPressureDiff = _atOrAfter.longPressure - _beforeOrAt.longPressure;
            uint _shortPressureDiff = _atOrAfter.shortPressure - _beforeOrAt.shortPressure;

            uint _timeDiff = ( _atOrAfter.time - _beforeOrAt.time ) * 1e18;

            uint _targetRatio = ( ( _target - _beforeOrAt.time ) * 1e18 ).divUp(_timeDiff);

            rollerThen_.longPressure = _beforeOrAt.longPressure.add(_longPressureDiff.mulDown(_targetRatio));
            rollerThen_.shortPressure = _beforeOrAt.shortPressure.add(_shortPressureDiff.mulDown(_targetRatio));
            rollerThen_.time = _target;

        }

    }

    function scryRollers (
        uint target
    ) internal view returns (
        Roller memory beforeOrAt, 
        Roller memory atOrAfter
    ) {

        beforeOrAt = rollers[index];

        // if the target is at or after the newest roller, we can return early 
        if (beforeOrAt.time <= target) {

            if (beforeOrAt.time == target) {

                // if newest roller equals target, we're in the same block, so we can ignore atOrAfter
                return (beforeOrAt, atOrAfter);

            } else {

                atOrAfter.time = block.timestamp;
                atOrAfter.longPressure = beforeOrAt.longPressure;
                atOrAfter.shortPressure = beforeOrAt.shortPressure;

                return (beforeOrAt, atOrAfter);

            }
        }

        // now, set before to the oldest roller
        uint _index = ( index + 1 ) % cardinality;
        beforeOrAt = rollers[_index];
        if ( beforeOrAt.time <= 1 ) {

            beforeOrAt = rollers[0];

        }

        if (target <= beforeOrAt.time) return ( beforeOrAt, beforeOrAt);
        else return binarySearch(
            rollers, 
            uint32(target), 
            uint16(index), 
            uint16(cardinality)
        );

    }

    function binarySearch(
        Roller[216000] storage self,
        uint32 target,
        uint16 _index,
        uint16 _cardinality
    ) private view returns (
        Roller memory beforeOrAt, 
        Roller memory atOrAfter
    ) {

        uint256 l = (_index + 1) % _cardinality; // oldest print
        uint256 r = l + _cardinality - 1; // newest print
        uint256 i;
        while (true) {
            i = (l + r) / 2;

            beforeOrAt = self[i % _cardinality];

            // we've landed on an uninitialized roller, keep searching 
            if (beforeOrAt.time <= 1) { l = i + 1; continue; }

            atOrAfter = self[(i + 1) % _cardinality];

            bool targetAtOrAfter = beforeOrAt.time <= target;

            if (targetAtOrAfter && target <= atOrAfter.time) break;

            if (!targetAtOrAfter) r = i - 1;
            else l = i + 1;
        }
    }

}