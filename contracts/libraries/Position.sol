// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "./FixedPoint.sol";

library Position {

    using FixedPoint for uint256;

    uint constant RESOLUTION = 1e4;

    struct Info {
        address market; // the market for the position
        bool isLong; // whether long or short
        uint leverage; // discrete initial leverage amount
        uint pricePoint; // pricePointIndex
        uint256 oiShares; // shares of total open interest on long/short side, depending on isLong value
        uint256 debt; // total debt associated with this position
        uint256 cost; // total amount of collateral initially locked; effectively, cost to enter position
        uint256 compounding; // timestamp when position is eligible for compound funding
    }

    function _openInterest(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares
    ) private pure returns (uint256 oi) {
        return _self.oiShares.mulUp(totalOi).divDown(totalOiShares);
    }

    /// @dev Floors to zero, so won't properly compute if self is underwater
    function _value(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceFrame
    ) private pure returns (uint256 val) {

        uint256 oi = _openInterest(_self, totalOi, totalOiShares);

        if (_self.isLong) {

            // oi * priceFrame - debt
            val = oi.mulDown(priceFrame);
            val -= Math.min(_self.debt, val); // floor to 0

        } else {

            // oi * (2 - priceFrame) - debt
            val = oi * 2;
            val -= Math.min(oi.mulDown(priceFrame) + _self.debt, val); // floor to 0

        }

    }

    /// @dev is true when position value < 0
    function _isUnderwater(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceFrame
    ) private pure returns (bool isUnder) {

        uint256 oi = _openInterest(_self, totalOi, totalOiShares);

        if (_self.isLong) {

            isUnder = oi.mulDown(priceFrame) < _self.debt;

        } else {

            isUnder = oi.mulDown(priceFrame) + _self.debt < oi * 2;

        }
    }

    /// @dev Floors to _self.debt, so won't properly compute if _self is underwater
    function _notional(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceFrame
    ) private pure returns (uint256 notion) {

        uint256 val = _value(
            _self,
            totalOi,
            totalOiShares,
            priceFrame
        );

        notion = val + _self.debt;

    }

    /// @dev ceils uint256.max if position value <= 0
    function _openLeverage(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceFrame
    ) private pure returns (uint lev) {

        uint val = _value(
            _self,
            totalOi,
            totalOiShares,
            priceFrame
        );

        if (val != 0) {

            uint256 notion = _notional(
                _self,
                totalOi,
                totalOiShares,
                priceFrame
            );

            lev = notion.divDown(val);

        } else lev = type(uint256).max;

    }

    /// @dev floors zero if position value <= 0; equiv to 1 / open leverage
    function _openMargin(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceFrame
    ) private pure returns (uint margin) {

        uint notion = _notional(
            _self,
            totalOi,
            totalOiShares,
            priceFrame
        );

        if (notion != 0) {

            uint256 val = _value(
                _self,
                totalOi,
                totalOiShares,
                priceFrame
            );

            margin = val.divDown(notion);

        } else margin = 0;

    }

    /// @dev is true when open margin < maintenance margin
    function _isLiquidatable(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceFrame,
        uint256 marginMaintenance
    ) private pure returns (bool can) {

        uint256 positionValue = _value(
            _self,
            totalOi,
            totalOiShares,
            priceFrame
        );

        uint maintenance = marginMaintenance.divDown(_self.leverage);

        can = positionValue < maintenance;

    }

    /// @notice Computes the open interest of a position
    function openInterest(
        Info storage self,
        uint256 totalOi,
        uint256 totalOiShares
    ) internal view returns (uint256) {

        Info memory _self = self;

        return _openInterest(_self, totalOi, totalOiShares);

    }

    /// @notice Computes the value of a position
    /// @dev Floors to zero, so won't properly compute if self is underwater
    function value(
        Info storage self,
        uint256 priceFrame,
        uint256 totalOi,
        uint256 totalOiShares
    ) internal view returns (uint256) {

        Info memory _self = self;

        return _value(
            _self,
            totalOi,
            totalOiShares,
            priceFrame
        );

    }

    /// @notice Whether position is underwater
    /// @dev is true when position value <= 0
    function isUnderwater(
        Info storage self,
        uint256 priceFrame,
        uint256 totalOi,
        uint256 totalOiShares
    ) internal view returns (bool) {

        Info memory _self = self;

        return _isUnderwater(
            _self,
            totalOi,
            totalOiShares,
            priceFrame
        );

    }

    /// @notice Computes the notional of a position
    /// @dev Floors to _self.debt, so won't properly compute if _self is underwater
    function notional(
        Info storage self,
        uint256 priceFrame,
        uint256 totalOi,
        uint256 totalOiShares
    ) internal view returns (uint256) {

        Info memory _self = self;

        return _notional(
            _self,
            totalOi,
            totalOiShares,
            priceFrame
        );

    }

    /// @notice Computes the open leverage of a position
    /// @dev ceils uint256.max if position value <= 0
    function openLeverage(
        Info storage self,
        uint256 priceFrame,
        uint256 totalOi,
        uint256 totalOiShares
    ) internal view returns (uint) {

        Info memory _self = self;

        return _openLeverage(
            _self,
            totalOi,
            totalOiShares,
            priceFrame
        );

    }

    /// @notice Computes the open margin of a position
    /// @dev floors zero if position value <= 0; equiv to 1 / open leverage
    function openMargin(
        Info storage self,
        uint256 priceFrame,
        uint256 totalOi,
        uint256 totalOiShares
    ) internal view returns (uint) {

        Info memory _self = self;

        return _openMargin(
            _self,
            totalOi,
            totalOiShares,
            priceFrame
        );

    }

    /// @notice Whether a position can be liquidated
    /// @dev is true when open margin < maintenance margin
    function isLiquidatable(
        Info storage self,
        uint256 priceFrame,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 marginMaintenance
    ) internal view returns (bool) {

        Info memory _self = self;

        return _isLiquidatable(
            _self,
            totalOi,
            totalOiShares,
            priceFrame,
            marginMaintenance
        );

    }

    /// @notice Computes the liquidation price of a position
    /// @dev TODO: ... function liquidationPrice()
}
