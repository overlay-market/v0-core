// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

contract OverlayV1Fees {
    // outstanding cumulative fees to be forwarded on update
    uint256 public fees;

    uint constant RESOLUTION = 1e4;

    /// @notice Adjusts state variable fee pots, which are transferred on call to update()
    function adjustForFees(
        uint256 notional,
        uint256 fee
    ) internal pure returns (uint256 notionalAdjusted, uint256 feeAmount) {
        notionalAdjusted = (notional * RESOLUTION - notional * fee) / RESOLUTION;
        feeAmount = notional - notionalAdjusted;
    }

    /// @notice Computes fee pot distributions and zeroes pot
    function updateFees(
        uint256 feeBurnRate,
        uint256 feeUpdateRewardsRate
    )
        internal
        returns (
            uint256 amountToBurn,
            uint256 amountToForward,
            uint256 amountToRewardUpdates
        )
    {
        uint256 feeAmount = fees;
        uint256 feeAmountLessBurn = (feeAmount * RESOLUTION - feeAmount * feeBurnRate) / RESOLUTION;
        uint256 feeAmountLessBurnAndUpdate = (feeAmountLessBurn * RESOLUTION - feeAmountLessBurn * feeUpdateRewardsRate) / RESOLUTION;

        amountToBurn = feeAmount - feeAmountLessBurn;
        amountToForward = feeAmountLessBurnAndUpdate;
        amountToRewardUpdates = feeAmountLessBurn - feeAmountLessBurnAndUpdate;

        // zero cumulative fees since last update
        fees = 0;
    }
}
