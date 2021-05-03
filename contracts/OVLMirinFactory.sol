// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IMirinFactory.sol";
import "./OVLMirinPosition.sol";
import "./OVLToken.sol";

contract OVLMirinFactory is Ownable {

    address public immutable ovl;
    address public immutable mirinFactory;

    mapping(address => bool) public isPosition;
    address[] public allPositions;

    constructor(address _ovl, address _mirinFactory) {
        ovl = _ovl;
        mirinFactory = _mirinFactory;
    }

    // deploys new position contract for given mirin pool address
    function deploy(address pool, uint256 cap, uint256 k) external onlyOwner returns (OVLMirinPosition position) {
        require(IMirinFactory(mirinFactory).isPool(pool), "!MirinPool");
        position = new OVLMirinPosition(mirinFactory, pool, cap, k);

        // Give position contract mint/burn priveleges for OVL token
        OVLToken(ovl).grantRole(OVLToken(ovl).MINTER_ROLE(), address(position));
        OVLToken(ovl).grantRole(OVLToken(ovl).BURNER_ROLE(), address(position));

        isPosition[address(position)] = true;
        allPositions.push(address(position));
    }

    // disables an existing position contract for a mirin market
    function disable(address position) external onlyOwner {
        require(isPosition[address(position)], "!enabled");
        isPosition[address(position)] = false;
    }
}
