// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IMirinOracle.sol";

contract MirinOracleMock is IMirinOracle, Ownable {

    struct PricePoint {
        uint256 timestamp;
        uint256 price0Cumulative;
        uint256 price1Cumulative;
    }

    PricePoint[] public override pricePoints;

    function addPricePoint(
        uint256 price0Cumulative,
        uint256 price1Cumulative
    ) public onlyOwner {
        pricePoints.push(PricePoint(block.timestamp, price0Cumulative, price1Cumulative));
    }

    function pricePointsLength() external override view returns (uint256) {
        return pricePoints.length;
    }
}
