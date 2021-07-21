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

    event Update(uint price, int256 fundingPaid);
    event Build(uint256 positionId, uint256 oi, uint256 debt);
    event Unwind(uint256 positionId, uint256 oi, uint256 debt);
    event Liquidate(address indexed rewarded, uint256 reward);

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

    /// @notice Updates funding payments, cumulative fees, queued position builds, and price points
    function update() public returns (bool updated_) {
        uint256 blockNumber = block.number;
        uint256 elapsed = (blockNumber - updateBlockLast) / updatePeriod;
        if (elapsed > 0) {

            // Funding payment changes at T+1
            int fundingPaid = updateFunding(fundingKNumerator, fundingKDenominator, elapsed);

            // Settle T < t < T+1 built positions at T+1 update
            // WARNING: Must come after funding to prevent funding harvesting w zero price risk
            uint256 newPrice = updatePricePoints();

            updateOi();

            // Increment update block
            updateBlockLast = blockNumber;

            emit Update(newPrice, fundingPaid);

            updated_ = true;

        }
    }

    function entryData (
        bool _isLong
    ) external returns (
        uint freeOi_,
        uint maxLev_,
        uint pricePointCurrent_
    ) {

        update();

        if (_isLong) freeOi_ = ( oiLast / 2 ) - oiLong;
        else freeOi_ = ( oiLast / 2 ) - oiShort;

        maxLev_ = leverageMax;

        pricePointCurrent_ = pricePoints.length;

    }

    function exitData (
        bool _isLong,
        uint256 _pricePoint
    ) public returns (
        uint oi_,
        uint oiShares_,
        uint priceFrame_
    ) {

        update();
        
        // TODO: fold in the update somewhere in here we could need 
        // to simultaneously get the entry and exit prices
        // TODO: how to do price getting with uni style

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
