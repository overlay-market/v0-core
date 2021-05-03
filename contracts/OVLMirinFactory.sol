// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IMirinFactory.sol";
import "./OVLMirinMarket.sol";
import "./OVLToken.sol";

contract OVLMirinFactory is Ownable {

    // ovl erc20 token
    address public immutable ovl;
    // mirin pool factory
    address public immutable mirinFactory;

    mapping(address => bool) public isMarket;
    address[] public allMarkets;

    constructor(address _ovl, address _mirinFactory) {
        ovl = _ovl;
        mirinFactory = _mirinFactory;
    }

    // deploys new market contract for given mirin pool address
    function deploy(
        address pool,
        uint256 cap,
        uint256 k
    ) external onlyOwner returns (OVLMirinMarket marketContract) {
        require(IMirinFactory(mirinFactory).isPool(pool), "!MirinPool");
        marketContract = new OVLMirinMarket(
            mirinFactory,
            pool,
            cap,
            k
        );

        isMarket[address(marketContract)] = true;
        allMarkets.push(address(marketContract));

        // Give position contract mint/burn priveleges for OVL token
        OVLToken(ovl).grantRole(OVLToken(ovl).MINTER_ROLE(), address(marketContract));
        OVLToken(ovl).grantRole(OVLToken(ovl).BURNER_ROLE(), address(marketContract));
    }

    // disables an existing market contract for a mirin market
    function disable(address market) external onlyOwner {
        require(isMarket[market], "!enabled");
        isMarket[market] = false;

        // Revoke mint/burn roles for the position
        OVLToken(ovl).revokeRole(OVLToken(ovl).MINTER_ROLE(), market);
        OVLToken(ovl).revokeRole(OVLToken(ovl).BURNER_ROLE(), market);
    }

    // enables an existing market contract for a mirin market
    function enable(address market) external onlyOwner {
        require(!isMarket[market], "!disabled");
        isMarket[market] = true;

        // Give position contract mint/burn priveleges for OVL token
        OVLToken(ovl).grantRole(OVLToken(ovl).MINTER_ROLE(), market);
        OVLToken(ovl).grantRole(OVLToken(ovl).BURNER_ROLE(), market);
    }

    // TODO: adjust(k, cap, leverages) to allow gov to adjust per market params
    function adjust(address market, uint256 cap, uint256 k) external onlyOwner {
        OVLMirinMarket(market).adjust(cap, k);
    }
}
