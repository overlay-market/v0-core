// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../interfaces/IOverlayV1Market.sol";
import "../OverlayToken.sol";

contract OverlayV1Mothership is AccessControlEnumerable {

    uint16 public constant MIN_FEE = 1; // 0.01%
    uint16 public constant MAX_FEE = 100; // 1.00%

    uint16 public constant MIN_MARGIN_MAINTENANCE = 100; // 1% maintenance
    uint16 public constant MAX_MARGIN_MAINTENANCE = 6000; // 60% maintenance

    bytes32 public constant GOVERNOR = keccak256("GOVERNOR");
    bytes32 public constant GUARDIAN = keccak256("GUARDIAN");
    bytes32 public constant MINTER = keccak256("MINTER");
    bytes32 public constant BURNER = keccak256("BURNER");

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
    mapping(address => bool) public marketActive;
    // whether is an already created market: for easy access instead of looping through allMarkets
    mapping(address => bool) public marketExists;

    mapping(address => bool) public collateralExists;
    mapping(address => bool) public collateralActive;
    address[] public allMarkets;

    modifier onlyGovernor () {
        require(hasRole(GOVERNOR, msg.sender), "OVLV1:!gov");
        _;
    }

    modifier onlyGuardian () {
        require(hasRole(GUARDIAN, msg.sender), "OVLV1:!guard");
        _;
    }

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
    function initializeMarket(address market) internal onlyGovernor {
        marketExists[market] = true;
        marketActive[market] = true;
        allMarkets.push(market);
    }

    /// @notice Disables an existing market contract for a mirin market
    function disableMarket(address market) external onlyGovernor {
        require(marketActive[market], "OVLV1: !enabled");
        marketActive[market] = false;
    }

    /// @notice Enables an existing market contract for a mirin market
    function enableMarket(address market) external onlyGovernor {
        require(marketExists[market], "OVLV1: !exists");
        require(!marketActive[market], "OVLV1: !disabled");
        marketActive[market] = true;
    }

    function enableCollateral (address _collateral) external onlyGovernor {
        require(collateralExists[_collateral], "OVLV1:!exists");
        require(!collateralActive[_collateral], "OVLV1:!disabled");
        OverlayToken(ovl).grantRole(OverlayToken(ovl).MINTER_ROLE(), _collateral);
        OverlayToken(ovl).grantRole(OverlayToken(ovl).BURNER_ROLE(), _collateral);
    }

    function disableCollateral (address _collateral) external onlyGovernor {
        require(collateralActive[_collateral], "OVLV1:!enabled");
        OverlayToken(ovl).revokeRole(OverlayToken(ovl).MINTER_ROLE(), _collateral);
        OverlayToken(ovl).revokeRole(OverlayToken(ovl).BURNER_ROLE(), _collateral);
    }

    /// @notice Allows gov to adjust per market params

    /// @notice Allows gov to adjust global params
    function adjustGlobalParams(
        uint16 _fee,
        uint16 _feeBurnRate,
        uint16 _feeUpdateRewardsRate,
        address _feeTo,
        uint16 _marginMaintenance,
        uint16 _marginBurnRate,
        uint16 _marginRewardRate
    ) external onlyGovernor {
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
