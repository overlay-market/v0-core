// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../libraries/FixedPoint.sol";

contract OverlayV1OI {

    event log(string k , uint v);

    using FixedPoint for uint256;

    // max number of periodSize periods before treat funding as completely rebalanced: done for gas savings on compute funding factor
    uint16 public constant MAX_FUNDING_COMPOUND = 4320; // 30d at 10m for updatePeriod
    uint256 private constant ONE = 1e18;

    uint256 internal __oiLong__; // total long open interest
    uint256 internal __oiShort__; // total short open interest

    uint256 internal __oiLongShares__; // total shares of long open interest outstanding
    uint256 internal __oiShortShares__; // total shares of short open interest outstanding

    uint256 internal __queuedOiLong__; // queued long open interest to be settled at T+1
    uint256 internal __queuedOiShort__; // queued short open interest to be settled at T+1

    uint256 public k;

    event FundingPaid(uint oiLong, uint oiShort, int fundingPaid);

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

        if (_oiLong == 0 && 0 == _oiShort) return (0, 0, 0);

        if (0 == _epochs) return ( _oiLong, _oiShort, 0 );

        uint _fundingFactor = ONE.sub(_k.mulUp(ONE*2));

        _fundingFactor = _fundingFactor.powUp(ONE*_epochs);

        uint _funder = _oiLong;
        uint _funded = _oiShort;
        bool payingLongs = _funder <= _funded;
        if (payingLongs) (_funder, _funded) = (_funded, _funder);

        if (_funded == 0) {

            uint _oiNow = _fundingFactor.mulDown(_funder);
            fundingPaid_ = int(_funder - _oiNow);
            _funder = _oiNow;

        } else {

            // TODO: we can make an unsafe mul function here
            uint256 _oiImbNow = _fundingFactor.mulDown(_funder - _funded);
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
    function payFunding (
        uint256 _k,
        uint256 _epochs
    ) internal returns (
        int256 fundingPaid_
    ) {

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
    function queueOi(
        bool _isLong,
        uint256 _oi,
        uint256 _oiCap
    ) internal {

        if (_isLong) {

            uint _queuedOiLong = __queuedOiLong__;
            _queuedOiLong += _oi;
            __queuedOiLong__ = _queuedOiLong;

            require(__oiLong__ + _queuedOiLong <= _oiCap, "OVLV1:>cap");

        } else {

            uint _queuedOiShort = __queuedOiShort__;
            _queuedOiShort += _oi;
            __queuedOiShort__ = _queuedOiShort;

            require(__oiShort__ + _queuedOiShort <= _oiCap, "OVLV1:>cap");

        }

    }

    function updateFunding (uint _epochs) internal returns (bool updated_) {

        if (0 < _epochs) {

            payFunding(k, _epochs); // WARNING: must pay funding before updating OI to avoid free rides

            updateOi();

            updated_ = true;

        }

    }


    /// @notice Updates open interest at T+1 price settlement
    /// @dev Execute at market update() to prevent funding payment harvest without price risk
    function updateOi() internal {

        uint _queuedOiLong = __queuedOiLong__;
        uint _queuedOiShort = __queuedOiShort__;

        __oiLong__ += _queuedOiLong;
        __oiShort__ += _queuedOiShort;
        __oiLongShares__ += _queuedOiLong;
        __oiShortShares__ += _queuedOiShort;

        __queuedOiLong__ = 0;
        __queuedOiShort__ = 0;

    }
}
