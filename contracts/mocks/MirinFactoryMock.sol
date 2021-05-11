// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MirinOracleMock.sol";

contract MirinFactoryMock is Ownable {

    mapping(address => bool) public isPool;
    address[] public allPools;

    function createPool() external returns (MirinOracleMock pool) {
        pool = new MirinOracleMock();
        isPool[address(pool)] = true;
        allPools.push(address(pool));
    }
}
