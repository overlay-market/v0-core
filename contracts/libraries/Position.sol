// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/math/Math.sol";

library Position {
    struct Info {
        bool isLong; // whether long or short
        uint256 leverage; // discrete initial leverage amount
        uint256 oiShares; // shares of total open interest on long/short side, depending on isLong value
        uint256 debt; // total debt associated with this position
        uint256 cost; // total amount of collateral initially locked; effectively, cost to enter position
    }

    function _value(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) private view returns (uint256 val) {
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

    function _notional(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) private view returns (uint256 notion) {
        uint256 val = _value(
            _self,
            totalOi,
            totalOiShares,
            priceEntry,
            priceExit
        );
        notion = val + _self.debt;
    }

    function _effectiveLeverage(
        Info memory _self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) private view returns (uint256 lev) {
        uint256 val = _value(
            _self,
            totalOi,
            totalOiShares,
            priceEntry,
            priceExit
        );
        if (val == 0) {
            lev = type(uint256).max;
        } else {
            uint256 notion = _notional(
                _self,
                totalOi,
                totalOiShares,
                priceEntry,
                priceExit
            );
            lev = notion / val;
        }
    }

    // computes the value of a position
    // NOTE: floors to zero, so won't properly compute if self is underwater
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

    // computes the notional of a position
    // NOTE: floors to self.debt, so won't properly compute if self is underwater
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

    // computes the effective leverage of a position
    // NOTE: ceils uint256.max if value() == 0
    function effectiveLeverage(
        Info storage self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) internal view returns (uint256) {
        Info memory _self = self;
        return _effectiveLeverage(
            _self,
            totalOi,
            totalOiShares,
            priceEntry,
            priceExit
        );
    }

    // TODO: function liquidationPrice(self, totalOi, totalOiShares, priceExit, marginRequirement) internal pure returns (uint256 val)
}
