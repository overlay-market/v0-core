// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../libraries/Position.sol";

contract OverlayV1Oi {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;
    using Position for Position.Info;

    // max number of periodSize periods before treat funding as completely rebalanced: done for gas savings on compute funding factor
    uint16 public constant MAX_FUNDING_COMPOUND = 4320; // 30d at 10m for updatePeriod

    // total long open interest
    uint256 public oiLong;
    // total short open interest
    uint256 public oiShort;

    // total shares of long open interest outstanding
    uint256 internal totalOiLongShares;
    // total shares of short open interest outstanding
    uint256 internal totalOiShortShares;

    // queued long open interest to be settled at T+1
    uint256 private queuedOiLong;
    // queued short open interest to be settled at T+1
    uint256 private queuedOiShort;

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
            factor = FixedPoint.pow(f, m);
        }
    }

    /// @notice Transfers funding payments
    /// @dev oiImbalance(m) = oiImbalance(0) * (1 - 2k)**m
    function updateFunding(
        uint112 fundingKNumerator,
        uint112 fundingKDenominator,
        uint256 elapsed
    ) internal returns (uint256 amountToBurn) {
        FixedPoint.uq144x112 memory fundingFactor = computeFundingFactor(
            fundingKDenominator - 2 * fundingKNumerator,
            fundingKDenominator,
            elapsed
        );
        if (oiShort == 0) {
            uint256 oiLongNow = fundingFactor.mul(oiLong).decode144();
            amountToBurn = oiLong - oiLongNow;
            oiLong = oiLongNow;
        } else if (oiLong == 0) {
            uint256 oiShortNow = fundingFactor.mul(oiShort).decode144();
            amountToBurn = oiShort - oiShortNow;
            oiShort = oiShortNow;
        } else if (oiLong > oiShort) {
            uint256 oiImbNow = fundingFactor.mul(oiLong - oiShort).decode144();
            oiLong = (oiLong + oiShort + oiImbNow) / 2;
            oiShort = (oiLong + oiShort - oiImbNow) / 2;
        } else {
            uint256 oiImbNow = fundingFactor.mul(oiShort - oiLong).decode144();
            oiShort = (oiLong + oiShort + oiImbNow) / 2;
            oiLong = (oiLong + oiShort - oiImbNow) / 2;
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
        totalOiLongShares += queuedOiLong;
        totalOiShortShares += queuedOiShort;

        queuedOiLong = 0;
        queuedOiShort = 0;
    }
}
