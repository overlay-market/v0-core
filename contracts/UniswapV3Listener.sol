// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./libraries/UniswapV3OracleLibrary/UniswapV3OracleLibrary.sol";
import "./interfaces/IUniV3Oracle.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./market/OverlayV1Market.sol";

contract UniswapV3Listener {

    address public immutable uniV3Pool;
    address public immutable token0;
    address public immutable token1;

    constructor(
        address _uniV3Pool
    ) {

        // immutables
        uniV3Pool = _uniV3Pool;
        token0 = IUniswapV3Pool(_uniV3Pool).token0();
        token1 = IUniswapV3Pool(_uniV3Pool).token1();

    }

    function see_tick () public view returns (int24) {

        return OracleLibrary.consult(uniV3Pool, 10 minutes, 0);

    }

    function listen (
        uint amountIn,
        address base
    ) public view returns (uint) {

        int24 tick = OracleLibrary.consult( uniV3Pool, 10 minutes, 0);

        uint gas = gasleft();
        uint quote = OracleLibrary.getQuoteAtTick(
            tick, 
            uint128(amountIn), 
            base == token0 ? token0 : token1,
            base != token0 ? token0 : token1
        );

        return quote;

    }

}
