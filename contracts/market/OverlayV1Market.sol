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

    function _update () internal virtual;

    function update () external { _update(); }

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
        uint impact_,
        uint pricePointCurrent_
    ) {

        _update();

        pricePointCurrent_ = _pricePoints.length;

        uint _oi = _collateral * _leverage;

        ( uint _impact, uint _cap ) = intake(_isLong, _oi);

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

        _update();

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
