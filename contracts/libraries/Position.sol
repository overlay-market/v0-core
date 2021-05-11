// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "./FixedPoint.sol";

library Position {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;

    struct Info {
        bool isLong; // whether long or short
        uint256 leverage; // discrete initial leverage amount
        uint256 oiShares; // shares of total open interest on long/short side, depending on isLong value
        uint256 debt; // total debt associated with this position
        uint256 cost; // total amount of collateral initially locked; effectively, cost to enter position
    }

    /// @dev Floors to zero, so won't properly compute if self is underwater
    function _value(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) private pure returns (uint256 val) {
        uint256 oi = _self.oiShares * totalOi / totalOiShares;
        if (_self.isLong) {
            // oi * priceExit / priceEntry - debt
            val = oi * priceExit / priceEntry;
            val -= Math.min(_self.debt, val); // floor to 0
        } else {
            // oi * (2 - priceExit / priceEntry) - debt
            val = oi * 2;
            val -= Math.min(oi * priceExit / priceEntry + _self.debt, val); // floor to 0
        }
    }

    /// @dev is true when position value < 0
    function _isUnderwater(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) private pure returns (bool isUnder) {
        uint256 oi = _self.oiShares * totalOi / totalOiShares;
        if (_self.isLong) {
            // val = oi * priceExit / priceEntry - debt
            isUnder = (oi * priceExit / priceEntry < _self.debt);
        } else {
            // val = oi * (2 - priceExit / priceEntry) - debt
            isUnder = (oi * 2 < _self.debt + oi * priceExit / priceEntry);
        }
    }

    /// @dev Floors to _self.debt, so won't properly compute if _self is underwater
    function _notional(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) private pure returns (uint256 notion) {
        uint256 val = _value(
            _self,
            totalOi,
            totalOiShares,
            priceEntry,
            priceExit
        );
        notion = val + _self.debt;
    }

    /// @dev ceils FixedPoint.uq144x112(uint256.max) if position value <= 0
    function _openLeverage(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) private pure returns (FixedPoint.uq144x112 memory lev) {
        // TODO: Fix for https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeCast.sol#L9
        // cast to uint112 given FixedPoint division by val
        uint112 val = uint112(_value(
            _self,
            totalOi,
            totalOiShares,
            priceEntry,
            priceExit
        ));
        if (val == 0) {
            lev = FixedPoint.uq144x112(type(uint256).max);
        } else {
            uint256 notion = _notional(
                _self,
                totalOi,
                totalOiShares,
                priceEntry,
                priceExit
            );
            lev = FixedPoint.uq144x112(notion).div(val);
        }
    }

    /// @dev floors zero if position value <= 0; equiv to 1 / open leverage
    function _openMargin(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) private pure returns (FixedPoint.uq144x112 memory margin) {
        // cast to uint112 given FixedPoint division by notion
        uint112 notion = uint112(_notional(
            _self,
            totalOi,
            totalOiShares,
            priceEntry,
            priceExit
        ));
        if (notion == 0) {
            margin = FixedPoint.uq144x112(0);
        } else {
            uint256 val = _value(
                _self,
                totalOi,
                totalOiShares,
                priceEntry,
                priceExit
            );
            margin = FixedPoint.uq144x112(val).div(notion);
        }
    }

    /// @dev checks open margin exceeds maintenance margin
    function _isLiquidatable(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit,
        uint16 maintenanceFactor,
        uint16 marginResolution
    ) private pure returns (bool can) {
        FixedPoint.uq144x112 memory margin = _openMargin(
            _self,
            totalOi,
            totalOiShares,
            priceEntry,
            priceExit
        );
        // TODO: Fix for safecasting: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeCast.sol#L9
        FixedPoint.uq144x112 memory maintenance = FixedPoint
            .uq144x112(uint256(maintenanceFactor))
            .div(uint112(marginResolution))
            .div(uint112(_self.leverage));
        can = margin.lt(maintenance);
    }

    /// @notice Computes the value of a position
    /// @dev Floors to zero, so won't properly compute if self is underwater
    function value(
        Info storage self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) internal view returns (uint256) {
        Info memory _self = self;
        return _value(
            _self,
            totalOi,
            totalOiShares,
            priceEntry,
            priceExit
        );
    }

    /// @notice Whether position is underwater
    /// @dev is true when position value <= 0
    function isUnderwater(
        Info storage self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) internal pure returns (bool) {
        Info memory _self = self;
        return _isUnderwater(
            _self,
            totalOi,
            totalOiShares,
            priceEntry,
            priceExit
        );
    }

    /// @notice Computes the notional of a position
    /// @dev Floors to _self.debt, so won't properly compute if _self is underwater
    function notional(
        Info storage self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) internal view returns (uint256) {
        Info memory _self = self;
        return _notional(
            _self,
            totalOi,
            totalOiShares,
            priceEntry,
            priceExit
        );
    }

    /// @notice Computes the open leverage of a position
    /// @dev ceils FixedPoint.uq144x112(uint256.max) if position value <= 0
    function openLeverage(
        Info storage self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) internal view returns (FixedPoint.uq144x112 memory) {
        Info memory _self = self;
        return _openLeverage(
            _self,
            totalOi,
            totalOiShares,
            priceEntry,
            priceExit
        );
    }

    /// @notice Computes the open margin of a position
    /// @dev floors zero if position value <= 0; equiv to 1 / open leverage
    function openMargin(
        Info storage self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) internal view returns (FixedPoint.uq144x112 memory) {
        Info memory _self = self;
        return _openMargin(
            _self,
            totalOi,
            totalOiShares,
            priceEntry,
            priceExit
        );
    }

    /// @notice Whether a position can be liquidated
    /// @dev checks open margin exceeds maintenance margin
    function isLiquidatable(
        Info storage self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit,
        uint16 maintenanceFactor,
        uint16 marginResolution
    ) internal view returns (bool) {
        Info memory _self = self;
        return _isLiquidatable(
            _self,
            totalOi,
            totalOiShares,
            priceEntry,
            priceExit,
            maintenanceFactor,
            marginResolution
        );
    }

    // TODO: function liquidationPrice(self, totalOi, totalOiShares, priceExit, marginRequirement) internal pure returns (uint256 val)
}
