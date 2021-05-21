// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../interfaces/IKeep3rV1.sol";
import "../interfaces/IOverlayFactory.sol";

contract OverlayMarketKeep3r {
    IKeep3rV1 public constant KP3R = IKeep3rV1(0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44);    
    IOverlayFactory public OVLF;
    address public rewardsTo;

    modifier upkeep() {
        require(KP3R.isKeeper(msg.sender), "OverlayMarketKeep3r: !keeper");
        _;
        KP3R.worked(msg.sender);
    }

    constructor(address _factory, address _rewardsTo) {
        OVLF = IOverlayFactory(_factory);
        rewardsTo = _rewardsTo;
    }

    function work() external upkeep {
        workUpdate();
        workLiquidate();
    }

    function workUpdate() public upkeep {
        OVLF.massUpdateMarkets(rewardsTo);
    }

    function workUpdate(address market) public upkeep {
        OVLF.updateMarket(market, rewardsTo);
    }

    // TODO: workLiquidate ..
    function workLiquidate() public upkeep {}
    function workLiquidate(address market) public upkeep {}
    function workLiquidate(address market, uint256 positionId) public upkeep {}
}
