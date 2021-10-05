// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../interfaces/IOverlayV1Mothership.sol";
import "../interfaces/IOverlayToken.sol";
import "./OverlayV1Comptroller.sol";
import "./OverlayV1OI.sol";
import "./OverlayV1PricePoint.sol";

abstract contract OverlayV1Governance is
    OverlayV1Comptroller,
    OverlayV1OI,
    OverlayV1PricePoint {

    uint constant private ONE = 1e18;

    bytes32 constant private COLLATERAL = keccak256("COLLATERAL");
    bytes32 constant private GOVERNOR = keccak256("GOVERNOR");
    bytes32 constant private MARKET = keccak256("MARKET");

    IOverlayToken public ovl;
    IOverlayV1Mothership public immutable mothership;

    uint256 public leverageMax;

    uint256 public priceFrameCap;

    uint256 public updatePeriod;
    uint256 public compoundingPeriod;

    mapping (address => bool) public isCollateral;

    modifier onlyCollateral () {
        require(isCollateral[msg.sender], "OVLV1:!collateral");
        _;
    }

    modifier onlyGovernor () {
        require(mothership.hasRole(GOVERNOR, msg.sender), "OVLV1:!governor");
        _;
    }

    modifier enabled() {
        require(mothership.hasRole(MARKET, address(this)), "OVLV1:!enabled");
        _;
    }

    constructor(address _mothership) {

        // immutables
        mothership = IOverlayV1Mothership(_mothership);
        ovl = IOverlayV1Mothership(_mothership).ovl();

    }

    function addCollateral (address _collateral) public onlyGovernor {

        isCollateral[_collateral] = true;

    }

    function removeCollateral (address _collateral) public onlyGovernor {

        isCollateral[_collateral] = false;

    }

    function setOVL () public onlyGovernor {

        ovl = mothership.ovl();

    }

    function setEverything (
        uint256 _k,
        uint256 _priceFrameCap,
        uint256 _pbnj,
        uint256 _updatePeriod,
        uint256 _compoundPeriod,
        uint256 _impactWindow,
        uint256 _staticCap,
        uint256 _lmbda,
        uint256 _brrrrFade
    ) public onlyGovernor {

        setK(_k);

        setPriceFrameCap(_priceFrameCap);

        setSpread(_pbnj);

        setPeriods(
            _updatePeriod,
            _compoundPeriod
        );

        setComptrollerParams(
            _impactWindow,
            _staticCap,
            _lmbda,
            _brrrrFade
        );

    }

    function setPriceFrameCap (
        uint256 _priceFrameCap
    ) public onlyGovernor {

        require(ONE < _priceFrameCap, "OVLV1:!priceFrame");

        priceFrameCap = _priceFrameCap;

    }

    function setSpread(
        uint256 _pbnj
    ) public onlyGovernor {

        pbnj = _pbnj;

    }

    function setK (
        uint256 _k
    ) public onlyGovernor {
        k = _k;
    }

    function setPeriods(
        uint256 _updatePeriod,
        uint256 _compoundingPeriod
    ) public onlyGovernor {

        // TODO: requires on params; particularly leverageMax wrt MAX_FEE and cap
        require(_updatePeriod >= 1, "OVLV1:!update");
        require(_updatePeriod <= _compoundingPeriod, "OVLV1:update>compound");

        updatePeriod = _updatePeriod;
        compoundingPeriod = _compoundingPeriod;

    }

    function setComptrollerParams (
        uint256 _impactWindow,
        uint256 _staticCap,
        uint256 _lmbda,
        uint256 _brrrrFade
    ) public onlyGovernor {

        impactWindow = _impactWindow;
        staticCap = _staticCap;
        lmbda = _lmbda;
        brrrrFade = _brrrrFade;

    }

}
