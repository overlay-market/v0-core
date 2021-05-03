// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

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
        address mirinPool,
        bool isPrice0,
        uint256 periodSize,
        uint256 windowSize,
        uint256 leverageMax,
        uint256 cap,
        uint256 k
    ) external onlyOwner returns (OVLMirinMarket marketContract) {
        require(IMirinFactory(mirinFactory).isPool(mirinPool), "!MirinPool");
        marketContract = new OVLMirinMarket(
            mirinFactory,
            mirinPool,
            isPrice0,
            periodSize,
            windowSize,
            leverageMax,
            cap,
            k
        );

        isMarket[address(marketContract)] = true;
        allMarkets.push(address(marketContract));

        // Give market contract mint/burn priveleges for OVL token
        OVLToken(ovl).grantRole(OVLToken(ovl).MINTER_ROLE(), address(marketContract));
        OVLToken(ovl).grantRole(OVLToken(ovl).BURNER_ROLE(), address(marketContract));
    }

    function exists(address market) private view returns (bool) {
        for (uint256 i=0; i < allMarkets.length; ++i) {
            if (market == allMarkets[i]) {
                return true;
            }
        }
        return false;
    }

    // disables an existing market contract for a mirin market
    function disable(address market) external onlyOwner {
        require(isMarket[market], "!enabled");
        isMarket[market] = false;

        // Revoke mint/burn roles for the market
        OVLToken(ovl).revokeRole(OVLToken(ovl).MINTER_ROLE(), market);
        OVLToken(ovl).revokeRole(OVLToken(ovl).BURNER_ROLE(), market);
    }

    // enables an existing market contract for a mirin market
    function enable(address market) external onlyOwner {
        require(!isMarket[market], "!disabled");
        require(exists(market), "!exists");
        isMarket[market] = true;

        // Give market contract mint/burn priveleges for OVL token
        OVLToken(ovl).grantRole(OVLToken(ovl).MINTER_ROLE(), market);
        OVLToken(ovl).grantRole(OVLToken(ovl).BURNER_ROLE(), market);
    }

    // adjust allows gov to adjust per market params
    function adjust(
        address market,
        uint256 periodSize,
        uint256 windowSize,
        uint256 leverageMax,
        uint256 cap,
        uint256 k
    ) external onlyOwner {
        OVLMirinMarket(market).adjust(
            periodSize,
            windowSize,
            leverageMax,
            cap,
            k
        );
    }
}
