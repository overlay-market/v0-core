// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IKeep3rV1 {
    function isKeeper(address) external returns (bool);
    function worked(address keeper) external;
}
