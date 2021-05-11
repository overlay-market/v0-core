// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./MirinOracleMock.sol";

contract MirinFactoryMock {

    mapping(address => bool) public isPool;
    address[] public allPools;

    function createPool(
        uint256[] memory timestamps,
        uint256[] memory price0Cumulatives,
        uint256[] memory price1Cumulatives
    ) external returns (MirinOracleMock pool) {
        pool = new MirinOracleMock(
            timestamps,
            price0Cumulatives,
            price1Cumulatives
        );
        isPool[address(pool)] = true;
        allPools.push(address(pool));
    }
}
