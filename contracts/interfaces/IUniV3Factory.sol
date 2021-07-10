// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IUniV3Factory {
    function isPool(address) external view returns (bool);
}
