// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../libraries/Position.sol";
import "../libraries/FixedPoint.sol";
import "../interfaces/IOverlayV1Mothership.sol";
import "./OverlayV1Governance.sol";
import "./OverlayV1OI.sol";
import "./OverlayV1PricePoint.sol";
import "../OverlayToken.sol";
import "./OverlayV1Comptroller.sol";

abstract contract OverlayV1Market is OverlayV1Governance {

    using FixedPoint for uint256;

    uint256 constant public MIN_COLLAT = 1e14;

    uint256 private unlocked = 1;

    modifier lock() { require(unlocked == 1, "OVLV1:!unlocked"); unlocked = 0; _; unlocked = 1; }

    constructor(address _mothership) OverlayV1Governance( _mothership) { }

    function _update (bool _readCap) internal virtual returns (uint cap_);

    function update () external { _update(false); }

    /// @notice Adds open interest to the market
    /// @dev This is invoked by Overlay collateral manager contracts, which
    /// can be for OVL, ERC20's, Overlay positions, NFTs, or what have you.
    /// The calculations for impact and fees are performed here.
    /// @param _isLong The side of the market to enter open interest on.
    /// @param _collateral The amount of collateral in OVL terms to take the
    /// position out with.
    /// @param _leverage The leverage with which to take out the position.
    /// @return oiAdjusted_ Amount of open interest after impact and fees.
    /// @return collateralAdjusted_ Amount of collateral after impact and fees.
    /// @return debtAdjusted_ Amount of debt after impact and fees.
    /// @return fee_ The protocol fee to be taken.
    /// @return impact_ The market impact for the build.
    /// @return pricePointNext_ The index of the price point for the position.
    function enterOI (
        bool _isLong,
        uint _collateral,
        uint _leverage
    ) external onlyCollateral returns (
        uint oiAdjusted_,
        uint collateralAdjusted_,
        uint debtAdjusted_,
        uint fee_,
        uint impact_,
        uint pricePointNext_
    ) {

        uint _cap = _update(true);

        pricePointNext_ = _pricePoints.length - 1;

        uint _oi = _collateral * _leverage;

        uint _impact = intake(_isLong, _oi, _cap);

        fee_ = _oi.mulDown(mothership.fee());

        impact_ = _impact;

        require(_collateral >= MIN_COLLAT + impact_ + fee_ , "OVLV1:collat<min");

        collateralAdjusted_ = _collateral - _impact - fee_;

        oiAdjusted_ = collateralAdjusted_ * _leverage;

        debtAdjusted_ = oiAdjusted_ - collateralAdjusted_;

        addOi(_isLong, oiAdjusted_, _cap);

    }

    function exitData (
        bool _isLong,
        uint256 _pricePoint
    ) public onlyCollateral returns (
        uint oi_,
        uint oiShares_,
        uint priceFrame_
    ) {

        _update(false);

        PricePoint storage priceEntry = _pricePoints[_pricePoint];

        PricePoint storage priceExit = _pricePoints[_pricePoints.length - 1];

        priceFrame_ = _isLong
            ? Math.min(priceExit.bid.divDown(priceEntry.ask), priceFrameCap)
            : priceExit.ask.divUp(priceEntry.bid);

        if (_isLong) ( oi_ = __oiLong__, oiShares_ = oiLongShares );
        else ( oi_ = __oiShort__, oiShares_ = oiShortShares );

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
        uint _oiShares,
        uint _brrrr,
        uint _antiBrrrr
    ) external onlyCollateral {

        brrrr( _brrrr, _antiBrrrr );

        if (_isLong) ( __oiLong__ -= _oi, oiLongShares -= _oiShares );
        else ( __oiShort__ -= _oi, oiShortShares -= _oiShares );

    }

}
