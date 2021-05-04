// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IMirinFactory.sol";

import "./OVLMirinMarket.sol";
import "./OVLToken.sol";

contract OVLMirinFactory is Ownable {

    uint16 public constant MIN_FEE = 1; // 0.01%
    uint16 public constant MAX_FEE = 100; // 1.00%
    uint16 public constant FEE_RESOLUTION = 10**4; // bps

    uint16 public constant MIN_MARGIN = 1; // 1% maintenance
    uint16 public constant MAX_MARGIN = 60; // 60% maintenance
    uint16 public constant MARGIN_RESOLUTION = 10**2; // percentage points

    // ovl erc20 token
    address public immutable ovl;
    // mirin pool factory
    address public immutable mirinFactory;

    // global params adjustable by gov
    // build/unwind trading fee
    uint16 public fee;
    // portion of build/unwind fee burnt
    uint16 public feeBurnRate;
    // address to send fees to
    address public feeTo;
    // maintenance margin requirement
    uint16 public margin;
    // maintenance margin burn rate on liquidations
    uint16 public marginBurnRate;
    // address to send margin to
    address public marginTo;

    mapping(address => bool) public isMarket;
    address[] public allMarkets;

    constructor(
        address _ovl,
        address _mirinFactory,
        uint16 _fee,
        uint16 _feeBurnRate,
        address _feeTo,
        uint16 _margin,
        uint16 _marginBurnRate,
        address _marginTo
    ) {
        // immutables
        ovl = _ovl;
        mirinFactory = _mirinFactory;

        // global params
        fee = _fee;
        feeBurnRate = _feeBurnRate;
        feeTo = _feeTo;
        margin = _margin;
        marginBurnRate = _marginBurnRate;
        marginTo = _marginTo;
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
        require(IMirinOracle(mirinPool).pricePointsLength() > 1, "!mirin initialized");
        marketContract = new OVLMirinMarket(
            ovl,
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

    // adjustPerMarket allows gov to adjust per market params
    function adjustPerMarket(
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

    // adjustGlobalP allows gov to adjust global params
    function adjustGlobal(
        uint16 _fee,
        uint16 _feeBurnRate,
        address _feeTo,
        uint16 _margin,
        uint16 _marginBurnRate,
        address _marginTo
    ) external onlyOwner {
        fee = _fee;
        feeBurnRate = _feeBurnRate;
        feeTo = _feeTo;
        margin = _margin;
        marginBurnRate = _marginBurnRate;
        marginTo = _marginTo;
    }

    function getGlobal()
        external
        view
        returns (
            uint16,
            uint16,
            uint16,
            address,
            uint16,
            uint16,
            uint16,
            address
        )
    {
        return (
            fee,
            feeBurnRate,
            FEE_RESOLUTION,
            feeTo,
            margin,
            marginBurnRate,
            MARGIN_RESOLUTION,
            marginTo
        );
    }
}
