// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../libraries/Position.sol";

contract OverlayV1OI {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;
    using Position for Position.Info;

    // max number of periodSize periods before treat funding as completely rebalanced: done for gas savings on compute funding factor
    uint16 public constant MAX_FUNDING_COMPOUND = 4320; // 30d at 10m for updatePeriod

    uint256 public oiLong; // total long open interest
    uint256 public oiShort; // total short open interest

    uint256 public oiLongShares; // total shares of long open interest outstanding
    uint256 public oiShortShares; // total shares of short open interest outstanding

    uint256 public queuedOiLong; // queued long open interest to be settled at T+1
    uint256 public queuedOiShort; // queued short open interest to be settled at T+1

    uint256 public updateLast;
    uint256 public oiLast;

    function data (bool _isLong) external view returns (
        uint oi_,
        uint oiShares_,
        uint totalOiShares_,
        uint freeOi_,
        uint pricePointCurrent_
    ) {

        if (_isLong) ( 
            totalOiShares_ = oiShares_ + oiShortShares, 
            oi_ = oiLong, 
            oiShares_ = oiLongShares 
        );
        else ( 
            totalOiShares_ = oiShares_ + oiLongShares,
            oi_ = oiShort, 
            oiShares_ = oiShortShares 
        );

        freeOi_ = ( oiLast / 2 ) - oi_;

    }

    function freeOi (
        bool _isLong
    ) public view returns (
        uint freeOi_
    ) {

        freeOi_ = oiLast / 2;

        if (_isLong) freeOi_ -= oiLong;
        else freeOi_ -= oiShort;

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

    /// @notice Transfers funding payments
    /// @dev oiImbalance(m) = oiImbalance(0) * (1 - 2k)**m
    function updateFunding(
        uint112 fundingKNumerator,
        uint112 fundingKDenominator,
        uint256 elapsed
    ) internal returns (int256 fundingPaid) {

        // TODO: can we remove safemath in this call - would need another library function
        FixedPoint.uq144x112 memory fundingFactor = computeFundingFactor(
            fundingKDenominator - 2 * fundingKNumerator,
            fundingKDenominator,
            elapsed
        );

        uint256 funding = oiLong;
        uint256 funded = oiShort;

        bool paidByShorts = funding <= funded;
        if (paidByShorts) (funding, funded) = (funded, funding);

        unchecked {

            if (funded == 0) {
                
                // TODO: we can make an unsafe mul function here
                uint256 oiNow = fundingFactor.mul(funding).decode144();
                fundingPaid = int(funding - oiNow);

                if (paidByShorts) oiShort = oiNow;
                else ( oiLong = oiNow, fundingPaid = -fundingPaid );

            } else {

                // TODO: we can make an unsafe mul function here
                uint256 oiImbNow = fundingFactor.mul(funding - funded).decode144();
                uint256 total = funding + funded;

                funding = ( total + oiImbNow ) / 2;
                funded = ( total - oiImbNow ) / 2;
                fundingPaid = int( oiImbNow / 2 );

                if (paidByShorts) ( oiShort = funding, oiLong = funded );
                else ( oiLong = funding, oiShort = funded, fundingPaid = -fundingPaid );

            }

        }

    }

    /// @notice Adds to queued open interest to prep for T+1 price settlement
    function queueOi(bool isLong, uint256 oi, uint256 oiCap) internal {
        if (isLong) {
            queuedOiLong += oi;
            require(oiLong + queuedOiLong <= oiCap, "OverlayV1: breached oi cap");
        } else {
            queuedOiShort += oi;
            require(oiShort + queuedOiShort <= oiCap, "OverlayV1: breached oi cap");
        }
    }

    /// @notice Updates open interest at T+1 price settlement
    /// @dev Execute at market update() to prevent funding payment harvest without price risk
    function updateOi() internal {
        oiLong += queuedOiLong;
        oiShort += queuedOiShort;
        oiLongShares += queuedOiLong;
        oiShortShares += queuedOiShort;

        queuedOiLong = 0;
        queuedOiShort = 0;
    }
}
