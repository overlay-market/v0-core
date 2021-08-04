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
    function updateFunding(
        uint112 _kNumerator,
        uint112 _kDenominator,
        uint256 _epochs
    ) internal returns (int256 fundingPaid_) {

        ( __oiLong__, __oiShort__, fundingPaid_ ) = computeFunding(
            __oiLong__,
            __oiShort__,
            _epochs,
            _kNumerator,
            _kDenominator
        );

    }

    /// @notice Adds to queued open interest to prep for T+1 price settlement
    function queueOi(bool isLong, uint256 oi, uint256 oiCap) internal {
        if (isLong) {
            queuedOiLong += oi;
            require(__oiLong__ + queuedOiLong <= oiCap, "OVLV1: breached oi cap");
        } else {
            queuedOiShort += oi;
            require(__oiShort__ + queuedOiShort <= oiCap, "OVLV1: breached oi cap");
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
