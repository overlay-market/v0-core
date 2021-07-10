// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./libraries/UniswapV3OracleLibrary/UniswapV3OracleLibrary.sol";
import "./interfaces/IUniV3Oracle.sol";
import "./market/OverlayV1Market.sol";

contract UniswapV3Listener {

    address public immutable uniV3Pool;

    address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor(
        address _uniV3Pool
    ) {

        // immutables
        uniV3Pool = _uniV3Pool;

    }

    function listen () public view returns (uint, uint) {

        int24 tick = OracleLibrary.consult(
            uniV3Pool, 
            120 minutes
        );

        uint gas = gasleft();
        uint quote = OracleLibrary.getQuoteAtTick(
            tick, 
            1e18, 
            weth,
            dai
        );

        return (quote, gas - gasleft());

    }

}
