// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


contract OverlayV1Comptroller {

    struct Roller {
        uint32 time;
        uint112 brrrr;
        uint112 longPressure;
        uint112 shortPressure;
    }

    uint256 public brrrrWindow;
    uint256 public impactWindow;

    uint24 public index;
    uint24 public cardinality;
    uint24 public cardinalityNext;
    Roller[216000] public rollers;

    constructor (
        uint _impactWindow,
        uint _brrrrWindow
    ) {

        cardinality = 1;
        cardinalityNext = 1;

        rollers[0] = Roller({
            time: uint32(block.timestamp),
            brrrr: 0,
            longPressure: 0,
            shortPressure: 0
        });

        impactWindow = _impactWindow;
        brrrrWindow = _brrrrWindow;
    }
    
    function expand (
        uint16 next
    ) public {

        require(cardinalityNext < next, 'OVLV1:next<curr');

        for (uint24 i = cardinalityNext; i < next; i++) rollers[i].time = 1;

        cardinalityNext = next;

    }

    function impactPressure (
        uint _oi
    ) internal view returns (uint _pressure) {

    }

    function intakePressure (
        bool _isLong,
        uint112 _oi
    ) internal returns (
        uint pressure_
    ){

        (   uint _lastMoment,
            Roller memory _rollerNow, 
            Roller memory _rollerThen ) = scry(impactWindow);

        if (_isLong) _rollerNow.longPressure += _oi;
        else _rollerNow.shortPressure += _oi;

        roll(_rollerNow, _lastMoment);

        pressure_ = _isLong
            ? _rollerNow.longPressure - _rollerThen.longPressure
            : _rollerNow.shortPressure - _rollerThen.shortPressure;

    }

    function noteBrrrr (
        uint112 _brrrr
    ) internal returns (
        uint112 brrrr_
    ){

        (   uint _lastMoment,
            Roller memory _rollerNow, 
            Roller memory _rollerThen ) = scry(brrrrWindow);

        _rollerNow.brrrr += _brrrr;

        roll(_rollerNow, _lastMoment);

        brrrr_ = _rollerNow.brrrr - _rollerThen.brrrr;

    }

    function scry (
        uint _ago
    ) internal returns (
        uint lastMoment_,
        Roller memory rollerNow_, 
        Roller memory rollerThen_
    ) {

        uint _time = block.timestamp;

        rollerNow_ = rollers[index];

        lastMoment_ = rollerNow_.time;

        if (block.timestamp != rollerNow_.time) rollerNow_.time = uint32(_time);

        uint _target = _time - _ago;

        (   Roller memory _beforeOrAt, 
            Roller memory _atOrAfter ) = scryRollers(_ago);

        if (_beforeOrAt.time == _target) {

            rollerThen_ = _beforeOrAt;

        } else if (_target == _atOrAfter.time) {

            rollerThen_ = _atOrAfter;

        } else {

            uint112 _brrrrDiff = _atOrAfter.brrrr - _beforeOrAt.brrrr * 1e10;
            uint112 _longPressureDiff = _atOrAfter.longPressure - _beforeOrAt.longPressure * 1e10;
            uint112 _shortPressureDiff = _atOrAfter.shortPressure - _beforeOrAt.shortPressure * 1e10;

            uint _timeDiff = _atOrAfter.time - _beforeOrAt.time * 1e10;

            uint112 _targetRatio = uint112( ( _target - _beforeOrAt.time ) / _timeDiff );

            rollerThen_.brrrr = _beforeOrAt.brrrr + ( _brrrrDiff * _targetRatio / 1e10 );
            rollerThen_.longPressure = _beforeOrAt.longPressure + ( _longPressureDiff * _targetRatio / 1e18 );
            rollerThen_.shortPressure = _beforeOrAt.shortPressure + ( _shortPressureDiff * _targetRatio / 1e18 );
            rollerThen_.time = uint32(_target);

        }


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

    function scryRollers (
        uint target
    ) public view returns (
        Roller memory beforeOrAt, 
        Roller memory atOrAfter
    ) {

        // now, set before to the oldest observation
        beforeOrAt = rollers[(index + 1) % cardinality];
        if ( beforeOrAt.time == 0 || beforeOrAt.time == 1 ) beforeOrAt = rollers[0];

        // ensure that the target is chronologically at or after the oldest observation
        require(beforeOrAt.time <= target, 'OLD');

        return binarySearch(
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
            if (beforeOrAt.time == 0 || beforeOrAt.time == 1) { l = i + 1; continue; }

            atOrAfter = self[(i + 1) % _cardinality];

            bool targetAtOrAfter = beforeOrAt.time <= target;

            if (targetAtOrAfter && target <= atOrAfter.time) break;

            if (!targetAtOrAfter) r = i - 1;
            else l = i + 1;
        }
    }

}

library RollerBytes {

    uint256 internal constant TIMESTAMP_OFFSET = 0;
    uint256 internal constant BRRRR_OFFSET = 32;
    uint256 internal constant LONG_PRESSURE_OFFSET = 107;
    uint256 internal constant SHORT_PRESSURE_OFFSET = 182;

    uint256 internal constant MASK_32 = 2**(32) - 1;
    uint256 internal constant MASK_75 = 2**(75) - 1;

    function decodeUint32(
        bytes32 word, 
        uint256 offset
    ) internal pure returns (uint256) {
        return uint256(word >> offset) & MASK_32;
    }

    function decodeUint75(
        bytes32 word, 
        uint256 offset
    ) internal pure returns (uint256) {
        return uint256(word >> offset) & MASK_75;
    }

    function insertUint32(
        bytes32 word,
        uint256 value,
        uint256 offset
    ) internal pure returns (bytes32) {
        bytes32 clearedWord = bytes32(uint256(word) & ~(MASK_32 << offset));
        return clearedWord | bytes32(value << offset);
    }

    function insertUint75(
        bytes32 word,
        uint256 value,
        uint256 offset
    ) internal pure returns (bytes32) {
        bytes32 clearedWord = bytes32(uint256(word) & ~(MASK_75 << offset));
        return clearedWord | bytes32(value << offset);
    }

}