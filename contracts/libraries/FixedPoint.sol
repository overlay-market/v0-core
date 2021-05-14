// SPDX-License-Identifier: MIT

// COPIED AND MODIFIED from SushiSwap
// https://github.com/sushiswap/mirin/blob/master/contracts/libraries/FixedPoint.sol
// commit hash 82ad73f6ac7e38f0ff8fcdf0e526118f537011e6

pragma solidity =0.8.2;

/**
 * @dev a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))
 * @author Andre Cronje
 */
library FixedPoint {
    // range: [0, 2**112 - 1]
    // resolution: 1 / 2**112
    struct uq112x112 {
        uint224 _x;
    }

    // range: [0, 2**144 - 1]
    // resolution: 1 / 2**112
    struct uq144x112 {
        uint256 _x;
    }

    uint8 private constant RESOLUTION = 112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 x) internal pure returns (uq112x112 memory) {
        return uq112x112(uint224(x) << RESOLUTION);
    }

    // encodes a uint144 as a UQ144x112
    function encode144(uint144 x) internal pure returns (uq144x112 memory) {
        return uq144x112(uint256(x) << RESOLUTION);
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function div(uq112x112 memory self, uint112 x) internal pure returns (uq112x112 memory) {
        require(x != 0, "FixedPoint: DIV_BY_ZERO");
        return uq112x112(self._x / uint224(x));
    }

    // multiply a UQ112x112 by a uint, returning a UQ144x112
    // reverts on overflow
    function mul(uq112x112 memory self, uint256 y) internal pure returns (uq144x112 memory) {
        return uq144x112(uint256(self._x) * y);
    }

    // divide a UQ144x112 by a uint112, returning a UQ144x112
    function div(uq144x112 memory self, uint112 x) internal pure returns (uq144x112 memory) {
        require(x != 0, "FixedPoint: DIV_BY_ZERO");
        return uq144x112(self._x / uint256(x));
    }

    // multiply a UQ144x112 by a uint, returning a UQ144x112
    // reverts on overflow
    function mul(uq144x112 memory self, uint256 y) internal pure returns (uq144x112 memory) {
        return uq144x112(self._x * y);
    }

    // divide a UQ144x112 by another UQ144x112, returning a UQ144x112
    function div(uq144x112 memory self, uq144x112 memory x) internal pure returns (uq144x112 memory) {
        require(x._x != 0, "FixedPoint: DIV_BY_ZERO");
        return uq144x112((self._x / x._x) << RESOLUTION);
    }

    // multiply a UQ144x112 by another UQ144x112, returning a UQ144x112
    // reverts on overflow
    function mul(uq144x112 memory self, uq144x112 memory y) internal pure returns (uq144x112 memory) {
        return uq144x112((self._x * y._x) >> RESOLUTION);
    }

    // returns a UQ112x112 which represents the ratio of the numerator to the denominator
    // equivalent to encode(numerator).div(denominator)
    function fraction(uint112 numerator, uint112 denominator) internal pure returns (uq112x112 memory) {
        require(denominator > 0, "FixedPoint: DIV_BY_ZERO");
        return uq112x112((uint224(numerator) << RESOLUTION) / denominator);
    }

    // XXX: returns a UQ144x112 which represents the ratio of the numerator to the denominator
    // equivalent to encode144(numerator).div(denominator)
    function fraction144(uint144 numerator, uint112 denominator) internal pure returns (uq144x112 memory) {
        require(denominator > 0, "FixedPoint: DIV_BY_ZERO");
        return uq144x112((uint256(numerator) << RESOLUTION) / denominator);
    }

    // returns a UQ144x112 which represents the ratio of numerator to denominator taken to the power of n (https://en.wikipedia.org/wiki/Exponentiation_by_squaring)
    // reverts on overflow
    function pow(FixedPoint.uq144x112 memory self, uint256 n) internal pure returns (uq144x112 memory) {
        if (n == 0) {
            return FixedPoint.encode144(1);
        } else if (n == 1) {
            return self;
        } else {
            // square then split into numerator and denominator
            uq144x112 memory sqrd = mul(self, self);
            if (n % 2 == 0) {
                return pow(sqrd, n/2);
            } else {
                return mul(pow(sqrd, (n-1)/2), self);
            }
        }
    }

    // XXX: compares whether UQ144x112 is greater than another UQ144x112
    function gt(uq144x112 memory self, uq144x112 memory y) internal pure returns (bool) {
        return self._x > y._x;
    }

    // XXX: compares whether UQ144x112 is less than another UQ144x112
    function lt(uq144x112 memory self, uq144x112 memory y) internal pure returns (bool) {
        return self._x < y._x;
    }

    // decode a UQ112x112 into a uint112 by truncating after the radix point
    function decode(uq112x112 memory self) internal pure returns (uint112) {
        return uint112(self._x >> RESOLUTION);
    }

    // decode a UQ144x112 into a uint144 by truncating after the radix point
    function decode144(uq144x112 memory self) internal pure returns (uint144) {
        return uint144(self._x >> RESOLUTION);
    }
}
