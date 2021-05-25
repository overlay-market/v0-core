// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

contract OverlayFees {
    // outstanding cumulative fees to be forwarded on update
    uint256 public fees;

    /// @notice Adjusts state variable fee pots, which are transferred on call to update()
    function adjustForFees(
        uint256 notional,
        uint256 fee,
        uint256 feeResolution
    ) internal pure returns (uint256 notionalAdjusted, uint256 feeAmount) {
        notionalAdjusted = (notional * feeResolution - notional * fee) / feeResolution;
        feeAmount = notional - notionalAdjusted;
    }

    /// @notice Computes fee pot distributions and zeroes pot
    function updateFees(
        uint256 feeBurnRate,
        uint256 feeUpdateRewardsRate,
        uint256 feeResolution
    )
        internal
        returns (
            uint256 amountToBurn,
            uint256 amountToForward,
            uint256 amountToRewardUpdates
        )
    {
        uint256 feeAmount = fees;
        uint256 feeAmountLessBurn = (feeAmount * feeResolution - feeAmount * feeBurnRate) / feeResolution;
        uint256 feeAmountLessBurnAndUpdate = (feeAmountLessBurn * feeResolution - feeAmountLessBurn * feeUpdateRewardsRate) / feeResolution;

        amountToBurn = feeAmount - feeAmountLessBurn;
        amountToForward = feeAmountLessBurnAndUpdate;
        amountToRewardUpdates = feeAmountLessBurn - feeAmountLessBurnAndUpdate;

        // zero cumulative fees since last update
        fees = 0;
    }
}
