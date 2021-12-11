// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../libraries/Position.sol";
import "../libraries/FixedPoint.sol";
import "../interfaces/IOverlayV1Mothership.sol";
import "./OverlayV1Choreographer.sol";
import "./OverlayV1OI.sol";
import "./OverlayV1PricePoint.sol";
import "../OverlayToken.sol";
import "./OverlayV1Comptroller.sol";

abstract contract OverlayV1Market is OverlayV1Choreographer {

    using FixedPoint for uint256;

    uint256 constant public MIN_COLLAT = 1e14;

    uint256 private unlocked = 1;

    modifier lock() { require(unlocked == 1, "OVLV1:!unlocked"); unlocked = 0; _; unlocked = 1; }

    constructor(
        address _mothership
    ) OverlayV1Choreographer (
        _mothership
    ) { }

    /**
      @notice Adds open interest to the market
      @dev This is invoked by Overlay collateral manager contracts, which
      @dev can be for OVL, ERC20's, Overlay positions, NFTs, or what have you.
      @dev The calculations for impact and fees are performed here.
      @dev Uses OverlayV1Choreographer contract struct: Tempo
      @dev Calls OverlayV1Comptroller contract function: intake
      @dev Calls Position contract function: mulDown
      @dev Calls OverlayV1OI contract function: addOi
      @param _isLong The side of the market to enter open interest on
      @param _collateral The amount of collateral in OVL terms to take the position out with
      @param _leverage The leverage with which to take out the position
      @return oiAdjusted_ Amount of open interest after impact and fees
      @return collateralAdjusted_ Amount of collateral after impact and fees
      @return debtAdjusted_ Amount of debt after impact and fees
      @return exactedFee_ The protocol fee to be taken
      @return impact_ The market impact for the build
      @return pricePointNext_ The index of the price point for the position
     */
    function enterOI (
      bool _isLong,
      uint _collateral,
        uint _leverage,
        uint _fee
    ) external onlyCollateral returns (
        uint oiAdjusted_,
        uint collateralAdjusted_,
        uint debtAdjusted_,
        uint exactedFee_,
        uint impact_,
        uint pricePointNext_
    ) {

        uint _cap;
        // Call to Position contract
        // Calculate open interest
        uint _oi = _collateral.mulDown(_leverage);

        // TODO
        OverlayV1Choreographer.Tempo memory _tempo = tempo;

        // Call to internal function
        // Updates the market with the latest price, cap, and pay funding
        (   _cap, 
            _tempo.updated, 
            _tempo.compounded ) = _update( 
                _tempo.updated,
                _tempo.compounded,
                _tempo.brrrrdCycloid
            );

        // Call to OverlayV1Comptroller contract
        // Takes in the OI and applies Overlay's monetary policy
        (   impact_,
            _tempo.impactCycloid,
            _tempo.brrrrdCycloid,
            _tempo.brrrrdFiling ) = intake(
                _isLong,
                _oi,
                _cap,
                _tempo.impactCycloid,
                _tempo.brrrrdCycloid,
                _tempo.brrrrdFiling
            );

        tempo = _tempo;

        pricePointNext_ = _pricePoints.length - 1;

        // Call to Position contract
        exactedFee_ = _oi.mulDown(_fee);

        require(_collateral >= MIN_COLLAT + impact_ + exactedFee_ , "OVLV1:collat<min");

        collateralAdjusted_ = _collateral - impact_ - exactedFee_;

        // Call to Position contract
        oiAdjusted_ = _leverage.mulUp(collateralAdjusted_);

        debtAdjusted_ = oiAdjusted_ - collateralAdjusted_;

        // Call to OverlayV1OI contract
        addOi(_isLong, oiAdjusted_, _cap);

    }


    /**
      @notice First part of the flow to remove OI from the system
      @dev This is called by the collateral managers to retrieve the necessary
      @dev information to calculate the specifics of each position, for
      @dev instance the PnL or if it is liquidatable. 
      @param _isLong Whether the data is being retrieved for a long or short
      @param _pricePoint Index of the initial price point
      @param oi_ Total outstanding open interest on that side of the market
      @param oiShares_ Total outstanding open interest shares on that side
      @param priceFrame_ The price multiple comprised of the entry and exit
      prices for the position, with the exit price being the current one. Longs
      receive the bid on exit and the ask on entry shorts the opposite
     */
    function exitData (
        bool _isLong,
        uint256 _pricePoint
    ) public onlyCollateral returns (
        uint oi_,
        uint oiShares_,
        uint priceFrame_
    ) {

        uint _updated;
        uint _compounded;

        OverlayV1Choreographer.Tempo memory _tempo = tempo;

        (  ,_tempo.updated, 
            _tempo.compounded ) = _update(
                _tempo.updated,
                _tempo.compounded,
                _tempo.brrrrdCycloid
            );

        tempo = _tempo;

        if (_isLong) ( oi_ = __oiLong__, oiShares_ = oiLongShares );
        else ( oi_ = __oiShort__, oiShares_ = oiShortShares );

        priceFrame_ = priceFrame(_isLong, _pricePoint);

    }

    /**
      @notice Removes open interest from the market
      @dev Called as the second part of exiting oi, this function reports the
      @dev open interest in OVL terms to remove as well as open interest shares
      @dev to remove. It also registers printing or burning of OVL in the
      @dev process.
      @param _isLong The side from which to remove open interest
      @param _oi The open interest to remove in OVL terms
      @param _oiShares The open interest shares to remove
      @param _brrrr How much was printed on closing the position
      @param _antiBrrrr How much was burnt on closing the position
     */
    function exitOI (
        bool _isLong,
        uint _oi,
        uint _oiShares,
        uint _brrrr,
        uint _antiBrrrr
    ) external onlyCollateral {

        OverlayV1Choreographer.Tempo memory _tempo = tempo;

        (   _tempo.brrrrdCycloid,
            _tempo.brrrrdFiling ) = brrrr( 
                _brrrr, 
                _antiBrrrr ,
                _tempo.brrrrdCycloid,
                _tempo.brrrrdFiling
            );

        tempo = _tempo;

        if (_isLong) ( __oiLong__ -= _oi, oiLongShares -= _oiShares );
        else ( __oiShort__ -= _oi, oiShortShares -= _oiShares );

    }

    /**
      @notice Public function that calls internal contract function _update, to
      @notice update price, cap, and pay funding.
      @dev This function calls the internal _update function which updates the
      @dev market with the latest price and conditionally reads the depth of
      @dev the market feed. The market needs an update on the first call of any
      @dev block.
      @dev Uses OverlayV1Choreographer contract struct: Tempo.
      @dev Calls the internal contract function: _update.
     */
    function update () public {

        OverlayV1Choreographer.Tempo memory _tempo = tempo;

        (  ,_tempo.updated, 
            _tempo.compounded ) = _update(
                _tempo.updated, 
                _tempo.compounded, 
                _tempo.brrrrdCycloid
            );

        tempo = _tempo;

    }

    /**
      @notice Internal function to update price, cap, and pay funding.
      @dev This function updates the market with the latest price and
      @dev conditionally reads the depth of the market feed. The market needs
      @dev an update on the first call of any block.
      @dev Calls OverlayV1PricePoint contract function: fetchPricePoint
      @dev Calls OverlayV1PricePoint contract function: setPricePointNext
      @dev Calls OverlayV1PricePoint contract function: pricePointCurrent
      @dev Calls OverlayV1OI contract function: epochs
      @dev Calls OverlayV1OI contract function: payFunding
      @dev Calls OverlayV1Comptroller contract function: oiCap
     */
    function _update (
        uint32 _updated,
        uint32 _compounded,
        uint8 _brrrrdCycloid
    ) internal virtual returns (
        uint cap_,
        uint32 updated_,
        uint32 compounded_
    ) {

        uint _depth;
        uint32 _now = uint32(block.timestamp);

        if (_now != _updated) {


            // Call to OverlayV1PricePoint contract
            PricePoint memory _pricePoint = fetchPricePoint();

            // Call to OverlayV1PricePoint contract
            setPricePointNext(_pricePoint);

            _depth = _pricePoint.depth;

            updated = _now;

        // Call to OverlayV1PricePoint contract
        } else (,,_depth) = pricePointCurrent();

        // Call to OverlayV1OI contract function
        (   uint32 _compoundings,
            uint32 _tCompounding  ) = epochs(_now, _compounded);

        if (0 < _compoundings) {

            // Call to OverlayV1OI contract
            payFunding(k, _compoundings);
            _compounded = _tCompounding;

        }

        // Call to OverlayV1Comptroller contract
        cap_ = _oiCap(_depth, _brrrrdCycloid);
        updated_ = _updated;
        compounded_ = _compounded;

    }

    function oiCap () public view virtual override returns (
        uint cap_
    ) {

        cap_ = _oiCap( depth() , tempo.brrrrdCycloid);

    }

    /**
      @notice The depth of the market feed in OVL terms at the current block.
      @dev Returns the time weighted liquidity of the market feed in OVL terms
      @dev at the current block.
      @return depth_ The time weighted liquidity in OVL terms.
     */
    function depth () public view override returns (
      uint depth_
    ) {

        ( ,,depth_ )= pricePointCurrent();

    }

}
