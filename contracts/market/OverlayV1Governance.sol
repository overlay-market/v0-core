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

    IOverlayToken public ovl;
    IOverlayV1Mothership public immutable mothership;

    mapping (address => bool) public isCollateral;

    bytes32 constant private COLLATERAL = keccak256("COLLATERAL");
    bytes32 constant private GOVERNOR = keccak256("GOVERNOR");
    bytes32 constant private MARKET = keccak256("MARKET");

    // leverage max allowed for a position: leverages are assumed to be discrete increments of 1
    uint256 public leverageMax;

    // open interest cap on each side long/short

    uint256 public updatePeriod;
    uint256 public compoundingPeriod;


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
        uint256 _leverageMax,
        uint256 _pbnj,
        uint256 _updatePeriod,
        uint256 _compoundPeriod,
        uint256 _impactWindow,
        uint256 _oiCap,
        uint256 _lambda,
        uint256 _brrrrFade
    ) public onlyGovernor {

        setK(_k);

        setLeverageMax(_leverageMax);

        setSpread(_pbnj);

        setPeriods(
            _updatePeriod, 
            _compoundPeriod
        );

        setComptrollerParams(
            _impactWindow,
            _oiCap,
            _lambda,
            _brrrrFade
        );

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

    function setLeverageMax (
        uint256 _leverageMax
    ) public onlyGovernor {

        leverageMax = _leverageMax;

    }

    function setPeriods(
        uint256 _updatePeriod,
        uint256 _compoundingPeriod
    ) public onlyGovernor {

        // TODO: requires on params; particularly leverageMax wrt MAX_FEE and cap
        require(_updatePeriod >= 1, "OVLV1:!update");
        require(_updatePeriod >= _compoundingPeriod, "OVLV1:update<compound");

        updatePeriod = _updatePeriod;
        compoundingPeriod = _compoundingPeriod;

    }

    function setComptrollerParams (
        uint256 _impactWindow,
        uint256 _oiCap,
        uint256 _lambda,
        uint256 _brrrrFade
    ) public onlyGovernor {

        impactWindow = _impactWindow;
        oiCap = _oiCap;
        lambda = _lambda;
        brrrrFade = _brrrrFade;

    }
    
}
