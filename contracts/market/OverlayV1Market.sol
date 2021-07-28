// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../libraries/Position.sol";
import "../interfaces/IOverlayV1Factory.sol";
import "./OverlayV1Governance.sol";
import "./OverlayV1OI.sol";
import "./OverlayV1Position.sol";
import "../OverlayToken.sol";

abstract contract OverlayV1Market is OverlayV1Governance, OverlayV1OI, OverlayV1PricePoint {

    mapping (address => bool) public isCollateral;

    uint256 public fees;
    uint256 public liquidations;

    uint constant RESOLUTION = 1e4;

    event CoreUpdate(uint price, int256 fundingPaid);

    uint16 public constant MIN_COLLATERAL_AMOUNT = 10**4;

    // block at which market update was last called: includes funding payment, fees, price fetching
    uint256 public updateBlockLast;

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "OVLV1:!unlocked");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyCollateral () {
        require(isCollateral[msg.sender], "OVLV1:!collateral");
        _;
    }

    constructor(
        address _ovl,
        uint256 _updatePeriod,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator,
        uint8   _leverageMax
    ) OverlayV1Governance(
        _ovl,
        _updatePeriod,
        _oiCap,
        _fundingKNumerator,
        _fundingKDenominator,
        _leverageMax
    ) {

        updateBlockLast = block.number;

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

    function staticUpdate () internal virtual returns (uint256 epochs_, uint256 price_);
    function entryUpdate () internal virtual returns (uint256 epochs_, uint256 price_);
    function exitUpdate () internal virtual returns (uint256 epochs_, uint256 price_);

    function updateFunding (uint _epochs, uint _newPrice) internal returns (bool updated_) {

        if (_epochs > 0) {

            // WARNING: must pay funding before updating OI to avoid free rides
            int _fundingPaid = updateFunding(
                fundingKNumerator, 
                fundingKDenominator, 
                _epochs
            );
            
            updateOi(); 

            updated_ = true;

            emit CoreUpdate(_newPrice, _fundingPaid);

        }
    }

    function update () external {

        ( uint _epochs, uint _price ) = staticUpdate();
        updateFunding(_epochs, _price);

    }

    function entryData (
        bool _isLong
    ) external onlyCollateral returns (
        uint freeOi_,
        uint maxLev_,
        uint pricePointCurrent_
    ) {

        ( uint _epochs, uint _newPrice  )= entryUpdate();
        updateFunding(_epochs, _newPrice);

        if (_isLong) freeOi_ = ( oiLast / 2 ) - oiLong;
        else freeOi_ = ( oiLast / 2 ) - oiShort;

        maxLev_ = leverageMax;

        pricePointCurrent_ = pricePoints.length;

    }

    function exitData (
        bool _isLong,
        uint256 _pricePoint
    ) public onlyCollateral returns (
        uint oi_,
        uint oiShares_,
        uint priceFrame_
    ) {

        ( uint _epochs, uint _newPrice ) = exitUpdate();
        updateFunding(_epochs, _newPrice);
        
        uint _priceEntry = pricePoints[_pricePoint];

        require( (_pricePoint = pricePoints.length - 1) < _pricePoint, "OVLV1:!settled");

        uint _priceExit = pricePoints[_pricePoint];

        priceFrame_ = _priceExit / _priceEntry;

        if (_isLong) ( oiShares_ = oiLongShares, oi_ = oiLong );
        else ( oiShares_ = oiShortShares, oi_ = oiLong );

    }

    /// @notice Adds open interest to the market
    /// @dev invoked by an overlay position contract
    function enterOI (
        bool _isLong,
        uint _oi
    ) external onlyCollateral {

        queueOi(_isLong, _oi, oiCap);

    }

    /// @notice Removes open interest from the market
    /// @dev must update two prices if the pending update was from a long 
    /// @dev time ago in that case, a previously entered position must be 
    /// @dev settled, and the current exit price must be retrieved
    /// @param _isLong is this from the short or the long side
    /// @param _oiShares the amount of oi in shares to be removed
    function exitOI (
        bool _isLong,
        uint _oi,
        uint _oiShares
    ) external onlyCollateral {

        if (_isLong) ( oiLong -= _oi, oiLongShares -= _oiShares );
        else ( oiShort -= _oi, oiShortShares -= _oiShares );

    }

}
