// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract OVLMirinPosition is ERC1155("https://metadata.overlay.exchange/mirin/{id}.json") {

    // OVLMirinFactory address
    address public immutable factory;

    // mirin pool and factory addresses
    address public immutable mirinFactory;
    address public immutable mirinPool;

    // open interest cap
    uint256 public cap;
    // open interest funding constant
    uint256 public k;

    // TODO: OI long, OI short, ...

    constructor(
        address _mirinFactory,
        address _mirinPool,
        uint256 _cap,
        uint256 _k
    ) {
        factory = msg.sender;
        mirinFactory = _mirinFactory;
        mirinPool = _mirinPool;
        cap = _cap;
        k = _k;
    }
}
