// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../interfaces/IOverlayToken.sol";

contract OverlayV1Fees {
    // outstanding cumulative fees to be forwarded on update
    uint256 public fees;
    uint256 public liquidations;

    uint constant RESOLUTION = 1e4;

    event Update(
        address indexed updater, 
        uint reward, 
        uint feeAmount, 
        uint feeBurn, 
        uint liquidationAmount,
        uint liquidationBurn
    );

    /// @notice Adjusts state variable fee pots, which are transferred on call to update()
    function adjustForFees(
        uint256 notional,
        uint256 fee
    ) internal pure returns (uint256 notionalAdjusted, uint256 feeAmount) {

        feeAmount = ( notional * fee ) / RESOLUTION;

        notionalAdjusted = notional - feeAmount;

    }

    /// @notice Computes fee pot distributions and zeroes pot
    function tallyFees(
        IOverlayToken ovl,
        uint256 fundingToBurn,
        uint256 marginBurnRate,
        uint256 feeBurnRate,
        uint256 feeRewardsRate,
        address feeTo
    )
        internal
        returns (
            uint256 amountToBurn,
            uint256 amountToReward,
            uint256 amountToForward
        )
    {

        uint256 feeAmount = fees;

        uint256 burnFee = ( feeAmount * feeBurnRate ) / RESOLUTION;

        uint256 updateFee = ( feeAmount * feeRewardsRate) / RESOLUTION;

        feeAmount = feeAmount - burnFee - updateFee;

        amountToBurn = fundingToBurn + burnFee;
        amountToReward = updateFee;
        amountToForward = feeAmount;

        uint liquidationAmount = liquidations;

        uint liquidationToBurn = ( liquidationAmount * marginBurnRate ) / RESOLUTION;

        liquidationAmount -= liquidationToBurn;

        amountToBurn += liquidationToBurn;

        amountToForward += liquidationAmount;

        // zero cumulative fees since last update
        fees = 0;

        liquidations = 0;

        emit Update(
            msg.sender,
            updateFee,
            feeAmount,
            burnFee,
            liquidationAmount,
            liquidationToBurn
        );

    }
}
