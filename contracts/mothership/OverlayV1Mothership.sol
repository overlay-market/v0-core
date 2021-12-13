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

    bytes32 public constant ADMIN = 0x00;
    bytes32 public constant GOVERNOR = keccak256("GOVERNOR");

    // ovl erc20 token
    address public immutable ovl;

    // portion of liquidations to burn on update
    uint public marginBurnRate;

    // global params adjustable by gov
    // build/unwind trading fee
    uint public fee;
    // portion of build/unwind fee burnt
    uint public feeBurnRate;
    // address to send fees to
    address public feeTo;

    mapping(address => bool) public marketActive;
    mapping(address => bool) public marketExists;
    address[] public allMarkets;

    mapping(address => bool) public collateralExists;
    mapping(address => bool) public collateralActive;
    address[] public allCollateral;

    event UpdateCollateral(address _collateral, bool _active);
    event UpdateMarket(address _market, bool _active);
    event UpdateGlobalParams(
        uint16 _fee,
        uint16 _feeBurnRate,
        address _feeTo,
        uint _marginBurnRate
    );

    modifier onlyGovernor () {
        require(hasRole(GOVERNOR, msg.sender), "OVLV1:!gov");
        _;
    }

    constructor(
        address _ovl,
        address _feeTo,
        uint _fee,
        uint _feeBurnRate,
        uint _marginBurnRate
    ) {

        _setupRole(ADMIN, msg.sender);
        _setupRole(GOVERNOR, msg.sender);
        _setRoleAdmin(GOVERNOR, ADMIN);

        // immutable params
        ovl = _ovl;

        // global params
        fee = _fee;
        feeBurnRate = _feeBurnRate;
        feeTo = _feeTo;
        marginBurnRate = _marginBurnRate;
    }

    function totalMarkets () external view returns (uint) {
        return allMarkets.length;
    }

    /// @notice Initializes an existing market contract after deployment
    /// @dev Should be called after contract deployment in specific market factory.createMarket
    function initializeMarket(address _market) external onlyGovernor {

        require(!marketExists[_market], "OVLV1: market exists");

        marketExists[_market] = true;
        marketActive[_market] = true;

        allMarkets.push(_market);

        emit UpdateMarket(_market, true);

    }

    /// @notice Disables an existing market contract for a mirin market
    function disableMarket(address _market) external onlyGovernor {

        require(marketActive[_market], "OVLV1: market !enabled");

        marketActive[_market] = false;

        emit UpdateMarket(_market, false);

    }

    /// @notice Enables an existing market contract for a mirin market
    function enableMarket(address _market) external onlyGovernor {

        require(marketExists[_market], "OVLV1: market !exists");

        require(!marketActive[_market], "OVLV1: market !disabled");

        marketActive[_market] = true;

        emit UpdateMarket(_market, true);

    }

    function initializeCollateral (address _collateral) external onlyGovernor {

        require(!collateralExists[_collateral], "OVLV1: collateral exists");

        collateralExists[_collateral] = true;
        collateralActive[_collateral] = true;

        allCollateral.push(_collateral);

        OverlayToken(ovl).grantRole(OverlayToken(ovl).MINTER_ROLE(), _collateral);

        OverlayToken(ovl).grantRole(OverlayToken(ovl).BURNER_ROLE(), _collateral);

        emit UpdateCollateral(_collateral, true);

    }

    function enableCollateral (address _collateral) external onlyGovernor {

        require(collateralExists[_collateral], "OVLV1: collateral !exists");

        require(!collateralActive[_collateral], "OVLV1: collateral !disabled");

        collateralActive[_collateral] = true;

        OverlayToken(ovl).grantRole(OverlayToken(ovl).MINTER_ROLE(), _collateral);

        OverlayToken(ovl).grantRole(OverlayToken(ovl).BURNER_ROLE(), _collateral);

        emit UpdateCollateral(_collateral, true);

    }

    function disableCollateral (address _collateral) external onlyGovernor {

        require(collateralActive[_collateral], "OVLV1: collateral !enabled");

        collateralActive[_collateral] = false;

        OverlayToken(ovl).revokeRole(OverlayToken(ovl).MINTER_ROLE(), _collateral);

        OverlayToken(ovl).revokeRole(OverlayToken(ovl).BURNER_ROLE(), _collateral);

        emit UpdateCollateral(_collateral, false);

    }

    /// @notice Allows gov to adjust global params
    function adjustGlobalParams(
        uint16 _fee,
        uint16 _feeBurnRate,
        address _feeTo,
        uint _marginBurnRate
    ) external onlyGovernor {
        fee = _fee;
        feeBurnRate = _feeBurnRate;
        feeTo = _feeTo;
        marginBurnRate = _marginBurnRate;

        emit UpdateGlobalParams(
            _fee,
            _feeBurnRate,
            _feeTo,
            _marginBurnRate
        );
    }

    function getUpdateParams() external view returns (
        uint,
        uint,
        address
    ) {
        return (
            marginBurnRate,
            feeBurnRate,
            feeTo
        );
    }

}
