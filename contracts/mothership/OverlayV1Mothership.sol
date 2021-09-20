// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "../interfaces/IOverlayV1Market.sol";
import "../OverlayToken.sol";

contract OverlayV1Mothership is Ownable {

    uint16 public constant MIN_FEE = 1; // 0.01%
    uint16 public constant MAX_FEE = 100; // 1.00%

    uint16 public constant MIN_MARGIN_MAINTENANCE = 100; // 1% maintenance
    uint16 public constant MAX_MARGIN_MAINTENANCE = 6000; // 60% maintenance

    uint16 public constant RESOLUTION = 10**4; // bps

    // ovl erc20 token
    address public immutable ovl;

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
    // maintenance margin reward rate on liquidations
    uint16 public marginRewardRate;
    // maintenance margin burn rate on liquidations
    uint16 public marginBurnRate;

    // whether is a market AND is enabled
    mapping(address => bool) public isMarket;
    // whether is an already created market: for easy access instead of looping through allMarkets
    mapping(address => bool) public marketExists;
    address[] public allMarkets;

    constructor(
        address _ovl,
        uint16 _fee,
        uint16 _feeBurnRate,
        uint16 _feeUpdateRewardsRate,
        address _feeTo,
        uint16 _marginMaintenance,
        uint16 _marginBurnRate,
        uint16 _marginRewardRate
    ) {
        // immutables
        ovl = _ovl;

        // global params
        fee = _fee;
        feeBurnRate = _feeBurnRate;
        feeUpdateRewardsRate = _feeUpdateRewardsRate;
        feeTo = _feeTo;
        marginMaintenance = _marginMaintenance;
        marginBurnRate = _marginBurnRate;
        marginRewardRate = _marginRewardRate;
    }

    function totalMarkets () external view returns (uint) {
        return allMarkets.length;
    }

    /// @notice Initializes an existing market contract after deployment
    /// @dev Should be called after contract deployment in specific market factory.createMarket
    function initializeMarket(address market) internal {
        marketExists[market] = true;
        isMarket[market] = true;
        allMarkets.push(market);

        // Give market contract mint/burn priveleges for OVL
        OverlayToken(ovl).grantRole(OverlayToken(ovl).MINTER_ROLE(), market);
        OverlayToken(ovl).grantRole(OverlayToken(ovl).BURNER_ROLE(), market);
    }

    /// @notice Disables an existing market contract for a mirin market
    function disableMarket(address market) external onlyOwner {
        require(isMarket[market], "OVLV1: !enabled");
        isMarket[market] = false;

        // Revoke mint/burn roles for the market
        OverlayToken(ovl).revokeRole(OverlayToken(ovl).MINTER_ROLE(), market);
        OverlayToken(ovl).revokeRole(OverlayToken(ovl).BURNER_ROLE(), market);
    }

    /// @notice Enables an existing market contract for a mirin market
    function enableMarket(address market) external onlyOwner {
        require(marketExists[market], "OVLV1: !exists");
        require(!isMarket[market], "OVLV1: !disabled");
        isMarket[market] = true;

        // Give market contract mint/burn priveleges for OVL token
        OverlayToken(ovl).grantRole(OverlayToken(ovl).MINTER_ROLE(), market);
        OverlayToken(ovl).grantRole(OverlayToken(ovl).BURNER_ROLE(), market);
    }

    /// @notice Allows gov to adjust per market params
    function adjustPerMarketParams(
        address market,
        uint256 updatePeriod,
        uint256 compoundingPeriod,
        uint144 oiCap,
        uint112 fundingKNumerator,
        uint112 fundingKDenominator,
        uint8 leverageMax
    ) external onlyOwner {
        IOverlayV1Market(market).adjustParams(
            updatePeriod,
            compoundingPeriod,
            oiCap,
            fundingKNumerator,
            fundingKDenominator,
            leverageMax
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
        uint16 _marginRewardRate
    ) external onlyOwner {
        fee = _fee;
        feeBurnRate = _feeBurnRate;
        feeUpdateRewardsRate = _feeUpdateRewardsRate;
        feeTo = _feeTo;
        marginMaintenance = _marginMaintenance;
        marginBurnRate = _marginBurnRate;
        marginRewardRate = _marginRewardRate;
    }

    function getUpdateParams() external view returns (
        uint16,
        uint16,
        uint16,
        address
    ) {
        return (
            marginBurnRate,
            feeBurnRate,
            feeUpdateRewardsRate,
            feeTo
        );
    }

    function getMarginParams() external view returns (
        uint16,
        uint16
    ) {
        return (
            marginMaintenance,
            marginRewardRate
        );
    }
}
