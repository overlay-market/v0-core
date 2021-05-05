// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/math/Math.sol";

library Position {
    struct Info {
        bool isLong; // whether long or short
        uint256 leverage; // discrete leverage amount
        uint256 oiShares; // shares of total open interest on long/short side, depending on isLong value
        uint256 debt; // total debt associated with this position
        uint256 cost; // total amount of collateral initially locked; effectively, cost to enter position
    }

    // computes the value of a position
    // NOTE: floors to zero, so won't properly compute if self is underwater
    function value(
        Info memory self,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) internal pure returns (uint256 val) {
        uint256 oi = self.oiShares * totalOi / totalOiShares;
        if (self.isLong) {
            // oi * priceExit / priceEntry - debt
            val = oi * priceExit / priceEntry;
            val -= Math.min(self.debt, val); // floor to 0
        } else {
            // oi * (2 - priceExit / priceEntry) - debt
            val = oi * 2;
            val -= Math.min(oi * priceExit / priceEntry + self.debt, val); // floor to 0
        }
    }

    // TODO: function liquidationPrice(self, totalOi, totalOiShares, priceExit, marginRequirement) internal pure returns (uint256 val)
}
