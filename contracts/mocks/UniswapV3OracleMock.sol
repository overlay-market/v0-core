
// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;


contract UniswapV3OracleMock {

    address public immutable token0;
    address public immutable token1;

    uint256 public index;
    int56[][] public observations;

    constructor(
        address _token0, 
        address _token1, 
        int56[][] memory _observations
    ) {

        token0 = _token0;
        token1 = _token1;

        uint len = _observations.length;
        for (uint i = 0; i < len; i++) observations.push(_observations[i]);

    }

    function seedObservations (
        int56[][] calldata _observations
    ) external {

        uint len = _observations.length;
        for (uint i = 0; i < len; i++) observations.push(_observations[i]);

    }

    function observeAndIncrement(
        uint32[] calldata secondsAgos
    ) external returns (
        int56[] memory tickCumulatives, 
        uint160[] memory secondsPerLiquidityCumulativeX128s
    ) {

        uint _index = index;
        index = _index + 1;

        int56[] memory tickCumulatives_ = observations[index];
        uint160[] memory secondsPerLiquidityCumulativeX128s_;

        return ( 
            tickCumulatives,
            secondsPerLiquidityCumulativeX128s
        );

    }

    function incrementIndex () public { 

        index += 1; 

    }

    function observe (
        uint32[] calldata secondsAgo
    ) external view returns (
        int56[] memory, 
        uint160[] memory
    ) {

        int56[] memory tickCumulatives_ = observations[index];
        uint160[] memory secondsPerLiquidityCumulativeX128s_;

        return ( 
            tickCumulatives_,
            secondsPerLiquidityCumulativeX128s_
        );

    }


}
