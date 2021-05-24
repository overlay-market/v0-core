// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IMirinFactory.sol";
import "./interfaces/IMirinOracle.sol";

import "./OverlayMirinMarket.sol";
import "./OverlayToken.sol";

contract OverlayMirinFactory is Ownable {

    uint16 public constant MIN_FEE = 1; // 0.01%
    uint16 public constant MAX_FEE = 100; // 1.00%
    uint16 public constant FEE_RESOLUTION = 10**4; // bps

    uint16 public constant MIN_MARGIN_MAINTENANCE = 1; // 1% maintenance
    uint16 public constant MAX_MARGIN_MAINTENANCE = 60; // 60% maintenance
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
    // portion of non-burned fees to reward market updaters with (funding + price)
    uint16 public feeUpdateRewardsRate;
    // address to send fees to
    address public feeTo;
    // maintenance margin requirement
    uint16 public marginMaintenance;
    // maintenance margin burn rate on liquidations
    uint16 public marginBurnRate;
    // address to send margin to
    address public marginTo;

    // whether is a market AND is enabled
    mapping(address => bool) public isMarket;
    // whether is an already created market: for easy access instead of looping through allMarkets
    mapping(address => bool) public marketExists;
    address[] public allMarkets;

    constructor(
        address _ovl,
        address _mirinFactory,
        uint16 _fee,
        uint16 _feeBurnRate,
        uint16 _feeUpdateRewardsRate,
        address _feeTo,
        uint16 _marginMaintenance,
        uint16 _marginBurnRate,
        address _marginTo
    ) {
        // immutables
        ovl = _ovl;
        mirinFactory = _mirinFactory;

        // global params
        fee = _fee;
        feeBurnRate = _feeBurnRate;
        feeUpdateRewardsRate = _feeUpdateRewardsRate;
        feeTo = _feeTo;
        marginMaintenance = _marginMaintenance;
        marginBurnRate = _marginBurnRate;
        marginTo = _marginTo;
    }

    /// @notice Creates a new market contract for given mirin pool address
    function createMarket(
        address mirinPool,
        bool isPrice0,
        uint256 updatePeriod,
        uint256 windowSize,
        uint8 leverageMax,
        uint16 marginAdjustment,
        uint144 oiCap,
        uint112 fundingKNumerator,
        uint112 fundingKDenominator,
        uint256 amountIn
    ) external onlyOwner returns (OverlayMirinMarket marketContract) {
        require(IMirinFactory(mirinFactory).isPool(mirinPool), "OverlayV1: !MirinPool");
        require(IMirinOracle(mirinPool).pricePointsLength() > 1, "OverlayV1: !MirinInitialized");
        marketContract = new OverlayMirinMarket(
            ovl,
            mirinPool,
            isPrice0,
            updatePeriod,
            windowSize,
            leverageMax,
            marginAdjustment,
            oiCap,
            fundingKNumerator,
            fundingKDenominator,
            amountIn
        );

        marketExists[address(marketContract)] = true;
        isMarket[address(marketContract)] = true;
        allMarkets.push(address(marketContract));

        // Give market contract mint/burn priveleges for OVL
        OverlayToken(ovl).grantRole(OverlayToken(ovl).MINTER_ROLE(), address(marketContract));
        OverlayToken(ovl).grantRole(OverlayToken(ovl).BURNER_ROLE(), address(marketContract));
    }

    /// @notice Disables an existing market contract for a mirin market
    function disableMarket(address market) external onlyOwner {
        require(isMarket[market], "OverlayV1: !enabled");
        isMarket[market] = false;

        // Revoke mint/burn roles for the market
        OverlayToken(ovl).revokeRole(OverlayToken(ovl).MINTER_ROLE(), market);
        OverlayToken(ovl).revokeRole(OverlayToken(ovl).BURNER_ROLE(), market);
    }

    /// @notice Enables an existing market contract for a mirin market
    function enableMarket(address market) external onlyOwner {
        require(marketExists[market], "OverlayV1: !exists");
        require(!isMarket[market], "OverlayV1: !disabled");
        isMarket[market] = true;

        // Give market contract mint/burn priveleges for OVL token
        OverlayToken(ovl).grantRole(OverlayToken(ovl).MINTER_ROLE(), market);
        OverlayToken(ovl).grantRole(OverlayToken(ovl).BURNER_ROLE(), market);
    }

    /// @notice Calls the update function on a market
    function updateMarket(address market, address rewardsTo) external {
        OverlayMirinMarket(market).update(rewardsTo);
    }

    /// @notice Mass calls update functions on all markets
    function massUpdateMarkets(address rewardsTo) external {
        for (uint256 i=0; i < allMarkets.length; ++i) {
            OverlayMirinMarket(allMarkets[i]).update(rewardsTo);
        }
    }

    /// @notice Allows gov to adjust per market params
    function adjustPerMarketParams(
        address market,
        uint256 updatePeriod,
        uint8 leverageMax,
        uint144 oiCap,
        uint112 fundingKNumerator,
        uint112 fundingKDenominator
    ) external onlyOwner {
        OverlayMirinMarket(market).adjustParams(
            updatePeriod,
            leverageMax,
            oiCap,
            fundingKNumerator,
            fundingKDenominator
        );
    }

    /// @notice Allows gov to adjust global params
    function adjustGlobalParams(
        uint16 _fee,
        uint16 _feeBurnRate,
        uint16 _feeUpdateRewardsRate,
        address _feeTo,
        uint16 _marginMaintenance,
        uint16 _marginBurnRate,
        address _marginTo
    ) external onlyOwner {
        fee = _fee;
        feeBurnRate = _feeBurnRate;
        feeUpdateRewardsRate = _feeUpdateRewardsRate;
        feeTo = _feeTo;
        marginMaintenance = _marginMaintenance;
        marginBurnRate = _marginBurnRate;
        marginTo = _marginTo;
    }

    function getGlobalParams()
        external
        view
        returns (
            uint16,
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
            feeUpdateRewardsRate,
            FEE_RESOLUTION,
            feeTo,
            marginMaintenance,
            marginBurnRate,
            MARGIN_RESOLUTION,
            marginTo
        );
    }
}
