// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

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

    uint256 public printWindow;
    struct Print {
        uint8  isinit;
        uint32 block;
        int216 printed;
    }

    int216 public printed;
    uint24 public index;
    uint24 public cardinality;
    uint24 public cardinalityNext;
    Print[216000] public prints;

    constructor (uint _printWindow) {

        cardinality = 1;
        cardinalityNext = 1;

        prints[0] = Print({
            isinit: 1,
            printed: 0,
            block: uint32(block.number)
        });

        printWindow = _printWindow;

    }

    function expand (
        uint16 next
    ) public {

        require(cardinalityNext < next, 'OVLV1:next<curr');

        // save write gas for the users
        for (uint24 i = cardinalityNext; i < next; i++) prints[i].block = 1;

        cardinalityNext = next;

    }

    function recordPrint (int216 _print) internal {
        uint24 _index = index;

        Print memory _last = prints[_index];
        if (_last.block != block.number) {

            uint24 _cardinality = cardinality;

            if (_index + 1 < _cardinality) {

                _index += 1;

                Print storage next = prints[_index];
                next.printed = _last.printed + printed;
                next.block = uint32(block.number);

            } else if (_cardinality < cardinalityNext) {

                _index += 1;
                cardinality += 1;

                Print storage next = prints[_index];
                next.printed = _last.printed + printed;
                next.block = uint32(block.number);
                next.isinit = 1;


            } else {

                _index = 0;
                Print storage next = prints[0];
                next.printed = _last.printed + printed;
                next.block = uint32(block.number);

            }

            index = _index;
            printed = _print;

        } else {

            printed += _print;

        }

    }

    function viewPrint (uint _ix) view public returns (Print memory _prints) {
        return prints[_ix];
    }

    function blocknumber () public view returns (uint ) { return block.number; }


    // TODO: should we include the current block?
    function printedInWindow () public view returns (int totalPrint_) {

        uint _target = block.number - printWindow;

        ( Print memory beforeOrAt,
          Print memory atOrAfter ) = getSurroundingPrints(_target);

        if (beforeOrAt.block == _target) {

            totalPrint_ = ( prints[index].printed + printed ) - beforeOrAt.printed;

        } else if (_target == atOrAfter.block) {

            totalPrint_ = ( prints[index].printed + printed ) - atOrAfter.printed;

        } else {

            int216 _printDiff = atOrAfter.printed - beforeOrAt.printed;
            uint _blockDiff = atOrAfter.block - beforeOrAt.block;

            uint _targetRatio = ( ( _target - beforeOrAt.block ) * 1e4 ) / _blockDiff;
            int _interpolatedPrint = beforeOrAt.printed + ( _printDiff * int(_targetRatio) );

            totalPrint_ = ( prints[index].printed + printed ) - _interpolatedPrint;

        }

    }

    function getSurroundingPrints (
        uint target
    ) public view returns (Print memory beforeOrAt, Print memory atOrAfter) {


        // now, set before to the oldest observation
        beforeOrAt = prints[(index + 1) % cardinality];
        if (beforeOrAt.isinit == 0) beforeOrAt = prints[0];

        // ensure that the target is chronologically at or after the oldest observation
        require(beforeOrAt.block <= target, 'OLD');

        return binarySearch(
            prints, 
            uint32(target), 
            uint16(index), 
            uint16(cardinality)
        );

    }

    function binarySearch(
        Print[216000] storage self,
        uint32 target,
        uint16 _index,
        uint16 _cardinality
    ) private view returns (Print memory beforeOrAt, Print memory atOrAfter) {
        uint256 l = (_index + 1) % _cardinality; // oldest print
        uint256 r = l + _cardinality - 1; // newest print
        uint256 i;
        while (true) {
            i = (l + r) / 2;

            beforeOrAt = self[i % _cardinality];

            // we've landed on an uninitialized tick, keep searching higher (more recently)
            if (beforeOrAt.isinit == 0) { l = i + 1; continue; }

            atOrAfter = self[(i + 1) % _cardinality];

            bool targetAtOrAfter = beforeOrAt.block <= target;

            // check if we've found the answer!
            if (targetAtOrAfter && target <= atOrAfter.block) break;

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
        uint112 fundingKNumerator,
        uint112 fundingKDenominator,
        uint256 m
    ) private pure returns (FixedPoint.uq144x112 memory factor) {
        if (m > MAX_FUNDING_COMPOUND) {
            // cut off the recursion if power too large
            factor = FixedPoint.encode144(0);
        } else {
            FixedPoint.uq144x112 memory f = FixedPoint.fraction144(
                fundingKNumerator,
                fundingKDenominator
            );
            // TODO: decide if we want to change to unsafe math inside pow
            factor = FixedPoint.pow(f, m);
        }
    }

    function computeFunding (
        uint256 _oiLong,
        uint256 _oiShort,
        uint256 _epochs,
        uint112 _kNumerator,
        uint112 _kDenominator
    ) internal pure returns (
        uint256 oiLong_,
        uint256 oiShort_,
        int256  fundingPaid_
    ) {

        if (0 == _epochs) return ( _oiLong, _oiShort, 0 );

        FixedPoint.uq144x112 memory fundingFactor = computeFundingFactor(
            _kDenominator - 2 * _kNumerator,
            _kDenominator,
            _epochs
        );

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
        uint112 _kNumerator,
        uint112 _kDenominator,
        uint256 _epochs
    ) internal returns (int256 fundingPaid_) {

        uint _oiLong;
        uint _oiShort;

        ( _oiLong, _oiShort, fundingPaid_ ) = computeFunding(
            __oiLong__,
            __oiShort__,
            _epochs,
            _kNumerator,
            _kDenominator
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

    // TODO: should we include the current block?
    function impact (uint _from, uint _to) public view returns (int totalPrint_) {

        uint _target = block.number - printWindow;

        ( Print memory beforeOrAt,
          Print memory atOrAfter ) = getSurroundingPrints(_target);

        if (beforeOrAt.block == _target) {

            totalPrint_ = ( prints[index].printed - beforeOrAt.printed;

        } else if (_target == atOrAfter.block) {

            totalPrint_ = ( prints[index].printed - atOrAfter.printed;

        } else {

            int216 _printDiff = atOrAfter.printed - beforeOrAt.printed;
            uint _blockDiff = atOrAfter.block - beforeOrAt.block;

            uint _targetRatio = ( ( _target - beforeOrAt.block ) * 1e4 ) / _blockDiff;
            int _interpolatedPrint = beforeOrAt.printed + ( _printDiff * int(_targetRatio) );

            totalPrint_ = ( prints[index].printed + printed ) - _interpolatedPrint;

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
