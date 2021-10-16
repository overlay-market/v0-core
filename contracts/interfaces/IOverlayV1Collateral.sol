

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../libraries/Position.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./IOverlayV1Market.sol";
import "./IOverlayV1Mothership.sol";
import "./IOverlayToken.sol";

interface IOverlayV1Collateral is IERC1155 {

    event log(string k, uint v);
    event log(string k, address v);

    event Build(
        address market, 
        uint256 positionId, 
        uint256 oi, 
        uint256 debt
    );
    event Unwind(
        address market,
        uint256 positionId, 
        uint256 oi, 
        uint256 debt
    );
    event Liquidate(
        uint256 positionId,
        uint256 oi,
        uint256 reward,
        address rewarded
    );
    event Update(
        address rewarded,
        uint rewardAmount,
        uint feesCollected,
        uint feesBurned,
        uint liquidationsCollected,
        uint liquidationsBurned
    );

    struct MarketInfo {
        uint marginMaintenance;
        uint marginRewardRate;
    }

    function totalSupply(uint256 positionId) external view returns (uint256 totalSupply);
    function marginAdjustments (address market) external view returns (uint256 marginAdjustment);
    function supportedMarket (address market) external view returns (bool supported);
    function queuedPositionLongs (address market, uint leverage) external view returns (uint queuedPositionId);
    function queuedPositionShorts (address market, uint leverage) external view returns (uint queuedPositionId);
    function positions (uint positionId) external view returns (Position.Info memory);
    function ovl () external view returns (IOverlayToken);
    function mothership () external view returns (IOverlayV1Mothership);
    function marketInfo(address) external view returns (MarketInfo memory);
    function fees () external view returns (uint);
    function liquidations () external view returns (uint);

    function setMarketInfo(
        address _market,
        uint _marginMaintenance,
        uint _marginRewardRate,
        uint _maxLeverage
    ) external;

    function marginMaintenance(
        address _market
    ) external view returns (
        uint marginMaintenance_
    );

    function marginRewardRate(
        address _market
    ) external view returns (
        uint marginRewardRate_
    );

    function maxLeverage(
        address _market
    ) external view returns (
        uint maxLeverage_
    );

    function addMarket (
        address _market,
        uint _marginAdjustment
    ) external;

    function update(
        address _market
    ) external;

    function build(
        address _market,
        uint256 _collateral,
        uint256 _leverage,
        bool _isLong
    ) external;

    function unwind(
        uint256 _positionId,
        uint256 _shares
    ) external;

    function liquidate(
        uint256 _positionId,
        address _rewardsTo
    ) external;

    function value (
        uint _positionId
    ) external view returns (uint);

}