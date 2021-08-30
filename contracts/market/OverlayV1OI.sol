// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../libraries/FixedPoint.sol";

contract OverlayV1OI {

    using FixedPoint for uint256;

    // max number of periodSize periods before treat funding as completely rebalanced: done for gas savings on compute funding factor
    uint16 public constant MAX_FUNDING_COMPOUND = 4320; // 30d at 10m for updatePeriod

    uint256 internal __oiLong__; // total long open interest
    uint256 internal __oiShort__; // total short open interest

    uint256 public oiLongShares; // total shares of long open interest outstanding
    uint256 public oiShortShares; // total shares of short open interest outstanding

    uint256 public queuedOiLong; // queued long open interest to be settled at T+1
    uint256 public queuedOiShort; // queued short open interest to be settled at T+1

    event FundingPaid(uint oiLong, uint oiShort, int fundingPaid);

    function freeOi (
        bool _isLong
    ) public view returns (
        uint freeOi_
    ) {

        // freeOi_ = oiLast / 2;

        if (_isLong) freeOi_ -= __oiLong__;
        else freeOi_ -= __oiShort__;

    }

    function computeFunding (
        uint256 _oiLong,
        uint256 _oiShort,
        uint256 _epochs,
        uint256 _k
    ) internal pure returns (
        uint256 oiLong_,
        uint256 oiShort_,
        int256  fundingPaid_
    ) {

        if (0 == _epochs) return ( _oiLong, _oiShort, 0 );

        uint fundingFactor = _k.powUp(_epochs);

        uint _funder = _oiLong;
        uint _funded = _oiShort;
        bool payingLongs = _funder <= _funded;
        if (payingLongs) (_funder, _funded) = (_funded, _funder);

        if (_funded == 0) {

            uint _oiNow = fundingFactor.mulDown(_funder);
            fundingPaid_ = int(_funder - _oiNow);
            _funder = _oiNow;

        } else {

            // TODO: we can make an unsafe mul function here
            uint256 _oiImbNow = fundingFactor.mulDown(_funder - _funded);
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
