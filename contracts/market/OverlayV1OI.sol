// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../libraries/Position.sol";

contract OverlayV1OI {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;
    using Position for Position.Info;

    // max number of periodSize periods before treat funding as completely rebalanced: done for gas savings on compute funding factor
    uint16 public constant MAX_FUNDING_COMPOUND = 4320; // 30d at 10m for updatePeriod

    uint256 internal __oiLong__; // total long open interest
    uint256 internal __oiShort__; // total short open interest

    uint256 public oiLongShares; // total shares of long open interest outstanding
    uint256 public oiShortShares; // total shares of short open interest outstanding

    uint256 public queuedOiLong; // queued long open interest to be settled at T+1
    uint256 public queuedOiShort; // queued short open interest to be settled at T+1

    uint256 public updateLast;
    uint256 public oiLast;

    uint256 public brrrrWindow;
    uint256 public impactWindow;
    struct Roller {
        uint8  init;
        uint32 time;
        int112 brrrr;
        int112 pressure;
    }

    int112 public brrrr;
    uint24 public index;
    uint24 public cardinality;
    uint24 public cardinalityNext;
    Roller[216000] public rollers;

    constructor (
        uint _brrrrWindow,
        uint _impactWindow
    ) {

        cardinality = 1;
        cardinalityNext = 1;

        rollers[0] = Roller({
            init: 1,
            time: uint32(block.timestamp),
            brrrr: 0,
            pressure: 0
        });

        brrrrWindow = _brrrrWindow;
        impactWindow = _impactWindow;

    }

    function expand (
        uint16 next
    ) public {

        require(cardinalityNext < next, 'OVLV1:next<curr');

        // save write gas for the users
        for (uint24 i = cardinalityNext; i < next; i++) {

            rollers[i].time = 1;

        }

        cardinalityNext = next;

    }

    function impactPressure (
        uint _oi
    ) internal view returns (uint _pressure) {

    }

    function recordImpact (
        int112 _oi
    ) internal returns (
        uint pressure_
    ){

        (   uint _lastMoment,
            Roller memory _rollerNow, 
            Roller memory _rollerThen ) = scry(impactWindow);

        _rollerNow.pressure += _oi;

        roll(_lastMoment, _rollerNow);

        pressure_ = _rollerNow.pressure - _rollerThen.pressure;

    }

    function recordBrrrr (
        uint112 _brrrr
    ) internal returns (
        uint112 brrrr_
    ){

        (   uint _lastMoment,
            Roller memory _rollerNow, 
            Roller memory _rollerThen ) = scry(brrrrWindow);

        _rollerNow.brrrr += _brrrr;

        roll(_lastMoment, _rollerNow);

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
            Roller memory _atOrAfter ) = getSurroundingRollers(_ago);

        if (_beforeOrAt.time == _target) {

            rollerThen_ = _beforeOrAt;

        } else if (_target == _atOrAfter.time) {

            rollerThen_ = _atOrAfter;

        } else {

            int112 _brrrrDiff = _atOrAfter.brrrr - _beforeOrAt.brrrr * 1e10;
            int112 _pressureDiff = _atOrAfter.pressure - _beforeOrAt.pressure * 1e10;

            uint _timeDiff = _atOrAfter.time - _beforeOrAt.time * 1e10;

            uint _targetRatio = ( _target - _beforeOrAt.time ) / _timeDiff;

            rollerThen_.brrrr = _beforeOrAt.brrrr + ( _brrrrDiff * _targetRatio / 1e10 );
            rollerThen_.pressure = _beforeOrAt.pressure + ( _pressureDiff * _targetRatio / 1e18 );
            rollerThen_.time = _target;

        }


    }

    function roll (
        Roller memory _roller,
        uint _before
    ) internal {

        uint24 _index = index;
        uint24 _cardinality = cardinality;
        uint24 _cardinalityNext = cardinalityNext;

        if (_roller.time != _before) {

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

    function blocknumber () public view returns (uint ) { return block.number; }

    function getSurroundingRollers (
        uint target
    ) public view returns (
        Roller memory beforeOrAt, 
        Roller memory atOrAfter
    ) {


        // now, set before to the oldest observation
        beforeOrAt = rollers[(index + 1) % cardinality];
        if (beforeOrAt.init == 0) beforeOrAt = rollers[0];

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
            if (beforeOrAt.init == 0) { l = i + 1; continue; }

            atOrAfter = self[(i + 1) % _cardinality];

            bool targetAtOrAfter = beforeOrAt.time <= target;

            if (targetAtOrAfter && target <= atOrAfter.time) break;

            if (!targetAtOrAfter) r = i - 1;
            else l = i + 1;
        }
    }

    event FundingPaid(uint oiLong, uint oiShort, int fundingPaid);

    function freeOi (
        bool _isLong
    ) public view returns (
        uint freeOi_
    ) {

        freeOi_ = oiLast / 2;

        if (_isLong) freeOi_ -= __oiLong__;
        else freeOi_ -= __oiShort__;

    }

    /// @notice Computes f**m
    /// @dev Works properly only when fundingKNumerator < fundingKDenominator
    function computeFundingFactor(
        uint112 fundingK,
        uint256 m
    ) private pure returns (FixedPoint.uq144x112 memory factor) {
        if (m > MAX_FUNDING_COMPOUND) {
            // cut off the recursion if power too large
            factor = FixedPoint.encode144(0);
        } else {
            // TODO: decide if we want to change to unsafe math inside pow
            // factor = FixedPoint.pow(fundingK, m);
        }
    }

    function computeFunding (
        uint256 _oiLong,
        uint256 _oiShort,
        uint256 _epochs,
        uint112 _k
    ) internal pure returns (
        uint256 oiLong_,
        uint256 oiShort_,
        int256  fundingPaid_
    ) {

        if (0 == _epochs) return ( _oiLong, _oiShort, 0 );

        FixedPoint.uq144x112 memory fundingFactor = computeFundingFactor( _k, _epochs);

        uint _funder = _oiLong;
        uint _funded = _oiShort;
        bool payingLongs = _funder <= _funded;
        if (payingLongs) (_funder, _funded) = (_funded, _funder);

        if (_funded == 0) {

            uint _oiNow = fundingFactor.mul(_funder).decode144();
            fundingPaid_ = int(_funder - _oiNow);
            _funder = _oiNow;

        } else {

            // TODO: we can make an unsafe mul function here
            uint256 _oiImbNow = fundingFactor.mul(_funder - _funded).decode144();
            uint256 _total = _funder + _funded;

            _funder = ( _total + _oiImbNow ) / 2;
            _funded = ( _total - _oiImbNow ) / 2;
            fundingPaid_ = int( _oiImbNow / 2 );

        }

        ( oiLong_, oiShort_, fundingPaid_) = payingLongs
            ? ( _funded, _funder, fundingPaid_ )
            : ( _funder, _funded, -fundingPaid_ );

    }

    /// @notice Transfers funding payments
    /// @dev oiImbalance(m) = oiImbalance(0) * (1 - 2k)**m
    function payFunding(
        uint112 _k,
        uint256 _epochs
    ) internal returns (int256 fundingPaid_) {

        uint _oiLong;
        uint _oiShort;

        ( _oiLong, _oiShort, fundingPaid_ ) = computeFunding(
            __oiLong__,
            __oiShort__,
            _epochs,
            _k
        );

        __oiLong__ = _oiLong;
        __oiShort__ = _oiShort;

        emit FundingPaid(_oiLong, _oiShort, fundingPaid_);

    }

    /// @notice Adds to queued open interest to prep for T+1 price settlement
    function queueOi(bool isLong, uint256 oi, uint256 oiCap) internal {
        if (isLong) {
            registerImpact(isLong, oi);
            queuedOiLong += oi;
            require(__oiLong__ + queuedOiLong <= oiCap, "OVLV1: breached oi cap");
        } else {
            registerImpact(isLong, oi);
            queuedOiShort += oi;
            require(__oiShort__ + queuedOiShort <= oiCap, "OVLV1: breached oi cap");
        }
    }

    function senseImpact() public view returns (uint longImpact_, uint shortImpact_) {

    }

    function registerImpact(bool _isLong, uint _oi) public {

    }

    // TODO: should we include the current block?
    function brrrr (uint _from, uint _to) public view returns (int totalPrint_) {

        uint _target = block.number - printWindow;

        ( Roller memory beforeOrAt,
          Roller memory atOrAfter ) = getSurroundingPrints(_target);

        if (beforeOrAt.time == _target) {

            totalPrint_ = rollers[index].brrrr - beforeOrAt.brrrr;

        } else if (_target == atOrAfter.time) {

            totalPrint_ = rollers[index].brrrr - atOrAfter.brrrr;

        } else {

            int216 _printDiff = atOrAfter.brrrr - beforeOrAt.brrrr;
            uint _blockDiff = atOrAfter.time - beforeOrAt.time;

            uint _targetRatio = ( ( _target - beforeOrAt.time ) * 1e4 ) / _blockDiff;
            int _interpolatedPrint = beforeOrAt.brrrr + ( _printDiff * int(_targetRatio) );

            totalPrint_ = ( rollers[index].brrrr + brrrr ) - _interpolatedPrint;

        }

    }


    /// @notice Updates open interest at T+1 price settlement
    /// @dev Execute at market update() to prevent funding payment harvest without price risk
    function updateOi() internal {

        __oiLong__ += queuedOiLong;
        __oiShort__ += queuedOiShort;
        oiLongShares += queuedOiLong;
        oiShortShares += queuedOiShort;

        queuedOiLong = 0;
        queuedOiShort = 0;
        
    }
}
