// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./UniswapV3OracleMock.sol";

contract UniswapV3FactoryMock {

    mapping(address => bool) public isPool;
    address[] public allPools;

    function createPool(
        address token0,
        address token1,
        int56[][] memory observations
    ) external returns (UniswapV3OracleMock pool) {
        pool = new UniswapV3OracleMock(
            token0,
            token1,
            observations
        );
        isPool[address(pool)] = true;
        allPools.push(address(pool));
    }

    function addObservationsPoints(
        address pool,
        int56[][] memory observations
    ) external {
        require(isPool[pool], "!pool");
        UniswapV3OracleMock(pool).addObservations(observations);
    }
}
