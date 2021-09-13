// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../libraries/Position.sol";
import "../libraries/FixedPoint.sol";
import "../interfaces/IOverlayV1Factory.sol";
import "./OverlayV1Governance.sol";
import "./OverlayV1OI.sol";
import "./OverlayV1PricePoint.sol";
import "../OverlayToken.sol";
import "./OverlayV1Comptroller.sol";

abstract contract OverlayV1Market is 
    OverlayV1Governance, 
    OverlayV1OI, 
    OverlayV1Comptroller,
    OverlayV1PricePoint {

    using FixedPoint for uint256;

    mapping (address => bool) public isCollateral;

    uint256 private unlocked = 1;

    modifier lock() { require(unlocked == 1, "OVLV1:!unlocked"); unlocked = 0; _; unlocked = 1; }

    modifier onlyCollateral () { require(isCollateral[msg.sender], "OVLV1:!collateral"); _; }

    constructor(
        address _ovl,
        uint256 _updatePeriod,
        uint256 _compoundingPeriod,
        uint256 _impactWindow,
        uint256 _brrrrFade,
        uint256 _oiCap,
        uint256 _fundingK,
        uint256 _leverageMax
    ) OverlayV1Governance (
        _ovl,
        _updatePeriod,
        _compoundingPeriod,
        _oiCap,
        _fundingK,
        _leverageMax
    ) OverlayV1Comptroller (
        _impactWindow
        _brrrrFade,
    ) { }

    function init (uint _lambda) public {
        lambda = _lambda;
    }

    function addCollateral (address _collateral) public {

        isCollateral[_collateral] = true;

    }
    
    function removeCollateral (address _collateral) public {

        isCollateral[_collateral] = false;

    }

    // compounding period - funding compound
    // update period - price update
    // printing period - rolling printing window

    // price points are updated at epoch timeframes
    // funding is paid and compounds by each epoch

    function staticUpdate () internal virtual returns (bool updated_);
    function entryUpdate () internal virtual returns (uint256 t1Compounding_);
    function exitUpdate () internal virtual returns (uint256 tCompounding_);

    function updateFunding (uint _epochs) internal returns (bool updated_) {

        if (_epochs > 0) {

            // WARNING: must pay funding before updating OI to avoid free rides
            payFunding(fundingK, _epochs);
            
            updateOi(); 

            updated_ = true;

        }
    }

    function update () external returns (bool updated_) {

        return staticUpdate();

    }


    /// @notice Adds open interest to the market
    /// @dev invoked by an overlay position contract
    function enterOI (
        bool _isLong,
        uint _collateral,
        uint _leverage
    ) external onlyCollateral returns (
        uint oiAdjusted_,
        uint collateralAdjusted_,
        uint debtAdjusted_,
        uint fee_,
        uint pricePointCurrent_,
        uint t1Compounding_
    ) {

        require(_leverage <= leverageMax, "OVLV1:lev>max");

        t1Compounding_ = entryUpdate();

        pricePointCurrent_ = pricePoints.length;

        uint _oi = _collateral * _leverage;

        ( uint _impact, uint _cap ) = intake(_isLong, _oi);

        fee_ = _oi.mulUp(factory.fee());

        collateralAdjusted_ = _collateral - _impact - fee_;

        oiAdjusted_ = collateralAdjusted_ * _leverage;

        debtAdjusted_ = oiAdjusted_ - collateralAdjusted_;

        queueOi(_isLong, oiAdjusted_, _cap);

    }

    function exitData (
        bool _isLong,
        uint256 _pricePoint
    ) public onlyCollateral returns (
        uint oi_,
        uint oiShares_,
        uint priceFrame_,
        uint compoundedEpoch_
    ) {

        compoundedEpoch_ = exitUpdate();

        PricePoint storage priceEntry = pricePoints[_pricePoint];

        require( (_pricePoint = pricePoints.length - 1) > _pricePoint, "OVLV1:!settled");

        PricePoint storage priceExit = pricePoints[_pricePoint];

        priceFrame_ = _isLong
            ? priceExit.bid / priceEntry.ask
            : priceExit.ask / priceEntry.bid;

        if (_isLong) ( oiShares_ = oiLongShares, oi_ = __oiLong__ + queuedOiLong );
        else ( oiShares_ = oiShortShares, oi_ = __oiShort__ + queuedOiShort );

    }

    /// @notice Removes open interest from the market
    /// @dev must update two prices if the pending update was from a long 
    /// @dev time ago in that case, a previously entered position must be 
    /// @dev settled, and the current exit price must be retrieved
    /// @param _isLong is this from the short or the long side
    /// @param _oiShares the amount of oi in shares to be removed
    function exitOI (
        bool _fromQueued,
        bool _isLong,
        uint _oi,
        uint _oiShares,
        int  _brrrr
    ) external onlyCollateral {

        brrrr(_brrrr);

        if (_fromQueued) {

            if (_isLong) queuedOiLong -= _oi;
            else queuedOiShort -= _oi;

        } else {

            if (_isLong) ( __oiLong__ -= _oi, oiLongShares -= _oiShares );
            else ( __oiShort__ -= _oi, oiShortShares -= _oiShares );

        }

    }

}
