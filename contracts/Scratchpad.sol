// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


contract Scratchpad {

    constructor () { }

    function one () internal pure returns (uint) {
        return 1;
    }

    function two () internal pure returns (uint) { 
        return 2;
    }

    function curry (function() internal pure returns(uint) func) internal pure returns (uint) {
        return func();
    }

    function one_and_two () public pure returns (uint, uint) {

        return (
            curry(one),
            curry(two)
        );

    }

}