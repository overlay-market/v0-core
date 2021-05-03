// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract OVLMirinPosition is ERC1155("https://metadata.overlay.exchange/mirin/{id}.json") {

    // OVLMirinFactory address
    address public immutable factory;

    // mirin pool and factory addresses
    address public immutable mirinFactory;
    address public immutable mirinPool;

    constructor(
        address _mirinFactory,
        address _mirinPool
    ) {
        factory = msg.sender;
        mirinFactory = _mirinFactory;
        mirinPool = _mirinPool;
    }
}
