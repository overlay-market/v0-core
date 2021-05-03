// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IMirinFactory.sol";
import "./OVLMirinPosition.sol";
import "./OVLToken.sol";

contract OVLMirinFactory is Ownable {

    address public immutable ovl;
    address public immutable mirinFactory;

    constructor(address _ovl, address _mirinFactory) {
        ovl = _ovl;
        mirinFactory = _mirinFactory;
    }

    // deploys new position contract for given mirin pool address
    function deploy(address pool) external onlyOwner returns (OVLMirinPosition position) {
        require(IMirinFactory(mirinFactory).isPool(pool), "!MirinPool");
        position = new OVLMirinPosition(mirinFactory, pool);

        // Give pool contract mint/burn priveleges for OVL token
        OVLToken(ovl).grantRole(OVLToken(ovl).MINTER_ROLE(), address(position));
        OVLToken(ovl).grantRole(OVLToken(ovl).BURNER_ROLE(), address(position));
    }
}
