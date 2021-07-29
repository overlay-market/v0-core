// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./UniswapV3OracleMock.sol";

contract UniswapV3FactoryMock {

    mapping(address => bool) public isPool;
    address[] public allPools;

    function createPool(
        uint _delay
    ) external returns (UniswapV3OracleMock pool) {
        pool = new UniswapV3OracleMock(_delay);
        isPool[address(pool)] = true;
        allPools.push(address(pool));
    }

    function addObservationPoints(
        address pool,
        OracleMock.Observation[] calldata _observations,
        UniswapV3OracleMock.Shim[] calldata _shims
    ) external {
        require(isPool[pool], "!pool");
        UniswapV3OracleMock(pool).loadObservations(_observations, _shims);
    }
}
