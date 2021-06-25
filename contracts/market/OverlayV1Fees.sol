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

        feeAmount = ( notional * fee ) / RESOLUTION;

        notionalAdjusted = notional - feeAmount;

    }

    /// @notice Computes fee pot distributions and zeroes pot
    function updateFees(
        uint256 feeBurnRate,
        uint256 feeUpdateRewardsRate
    )
        internal
        returns (
            uint256 amountToBurn,
            uint256 amountToReward,
            uint256 amountToForward
        )
    {

        uint256 feeAmount = fees;

        uint256 burnFee = ( feeAmount * ( feeBurnRate ) ) / RESOLUTION;

        uint256 updateFee = ( feeAmount * ( feeUpdateRewardsRate) ) / RESOLUTION;

        amountToBurn = burnFee;
        amountToReward = updateFee;
        amountToForward = feeAmount - burnFee - updateFee;

        // zero cumulative fees since last update
        fees = 0;

    }
}
