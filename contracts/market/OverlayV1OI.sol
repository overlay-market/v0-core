// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../libraries/FixedPoint.sol";

contract OverlayV1OI {

    // event log(string k , uint v);

    using FixedPoint for uint256;

    uint256 private constant ONE = 1e18;

    uint256 public compoundingPeriod;
    uint256 public compounded;

    uint256 internal __oiLong__; // total long open interest
    uint256 internal __oiShort__; // total short open interest

    uint256 public oiLongShares; // total shares of long open interest outstanding
    uint256 public oiShortShares; // total shares of short open interest outstanding

    uint256 public k;

    event FundingPaid(uint oiLong, uint oiShort, int fundingPaid);


    /// @notice Internal utility to pay funding from heavier to ligher side.
    /// @dev Pure function accepting current open interest, compoundings
    /// to perform, and funding constant.
    /// @dev oiImbalance(period_m) = oiImbalance(period_now) * (1 - 2k) ** period_m
    /// @param _oiLong Current open interest on the long side.
    /// @param _oiShort Current open interest on the short side.
    /// @param _epochs The number of compounding periods to compute for.
    /// @param _k The funding constant.
    /// @return oiLong_ Open interest on the long side after funding is paid.
    /// @return oiShort_ Open interest on the short side after funding is paid.
    /// @return fundingPaid_ Signed integer of funding paid, negative if longs
    /// are paying shorts.
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

            fundingPaid_ = int( ( _funder - _funded ) / 2 );
            _funder = ( _total + _oiImbNow ) / 2;
            _funded = ( _total - _oiImbNow ) / 2;

        }

        ( oiLong_, oiShort_, fundingPaid_) = payingLongs
            ? ( _funded, _funder, fundingPaid_ )
            : ( _funder, _funded, -fundingPaid_ );

    }


    /// @notice Pays funding.
    /// @dev Invokes internal computeFunding and sets oiLong and oiShort.
    /// @param _k The funding constant.
    /// @param _epochs The number of compounding periods to compute.
    /// @return fundingPaid_ Signed integer of how much funding was paid.
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

    /// @notice Adds open interest to one side
    /// @dev Adds open interest to one side, asserting the cap is not breached.
    /// @param _isLong If open interest is adding to the long or short side.
    /// @param _oi Open interest to add.
    /// @param _oiCap Open interest cap to require not to be breached.
    function addOi(
        bool _isLong,
        uint256 _oi,
        uint256 _oiCap
    ) internal {

        if (_isLong) {

            oiLongShares += _oi;

            uint _oiLong = __oiLong__ + _oi;

            require(_oiLong <= _oiCap, "OVLV1:>cap");

            __oiLong__ = _oiLong;

        } else {

            oiShortShares += _oi;

            uint _oiShort = __oiShort__ + _oi;

            require(_oiShort <= _oiCap, "OVLV1:>cap");

            __oiShort__ = _oiShort;

        }

    }

}
