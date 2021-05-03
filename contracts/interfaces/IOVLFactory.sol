// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOVLFactory {
    function isMarket(address) external view returns (bool);
}
