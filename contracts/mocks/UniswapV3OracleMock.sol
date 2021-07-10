
// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;


contract UniswapV3OracleMock {

    address public immutable token0;
    address public immutable token1;

    uint index;
    int56[2][] observations;

    constructor(
        address _token0, 
        address _token1, 
        uint128 _liquidity
    ) {

        token0 = _token0;
        token1 = _token1;

    }

    function seedObservations (
        int56[2][] calldata _observations
    ) external {

        uint len = _observations.length;

        for (uint i = 0; i < len; i++){

            observations[i] = _observations[i];

        }

    }

    function observe(
        uint32[] calldata secondsAgos
    ) external returns (
        int56[2] memory tickCumulatives, 
        uint160[2] memory secondsPerLiquidityCumulativeX128s
    ) {

        uint _index = index;
        index = _index + 1;

        int56[2] memory tickCumulatives = observations[_index];
        uint160[2] memory secondsPerLiquidityCumulativeX128s;

        return ( 
            tickCumulatives,
            secondsPerLiquidityCumulativeX128s
        );

    }


    function observeView(
        uint32[] calldata secondsAgos
    ) external view returns (
        int56[2] memory tickCumulatives, 
        uint160[2] memory secondsPerLiquidityCumulativeX128s
    ) {

        int56[2] memory tickCumulatives = observations[index];
        uint160[2] memory secondsPerLiquidityCumulativeX128s;

        return ( 
            tickCumulatives,
            secondsPerLiquidityCumulativeX128s
        );

    }


}
