// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../interfaces/IKeep3rV1.sol";
import "../interfaces/IOVLFactory.sol";

contract OVLMirinKeep3r {
    IKeep3rV1 public constant KP3R = IKeep3rV1(0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44);
    IOVLFactory public constant OVLMF = IOVLFactory(address(0)); // TODO: Fill in address once OVLMirinFactory launched

    address public rewardsTo;

    modifier upkeep() {
        require(KP3R.isKeeper(msg.sender), "OVLMirinKeep3r: !keeper");
        _;
        KP3R.worked(msg.sender);
    }

    constructor(address _rewardsTo) {
        rewardsTo = _rewardsTo;
    }

    function workUpdate() external upkeep {
        OVLMF.massUpdateMarkets(rewardsTo);
    }

    function workUpdate(address market) external upkeep {
        OVLMF.updateMarket(market, rewardsTo);
    }

    // TODO: workLiquidate ...
}
