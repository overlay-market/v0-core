// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../libraries/FixedPoint.sol";

contract MathTest {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;

    uint8 public constant RESOLUTION = 112;

    function div(uint144 nx, uint112 dx, uint144 ny, uint112 dy) public pure returns (uint144) {
        FixedPoint.uq144x112 memory x = FixedPoint.fraction144(nx, dx);
        FixedPoint.uq144x112 memory y = FixedPoint.fraction144(ny, dy);
        return FixedPoint.div(x, y).decode144();
    }

    function mul(uint144 nx, uint112 dx, uint144 ny, uint112 dy) public pure returns (uint144) {
        FixedPoint.uq144x112 memory x = FixedPoint.fraction144(nx, dx);
        FixedPoint.uq144x112 memory y = FixedPoint.fraction144(ny, dy);
        return FixedPoint.mul(x, y).decode144();
    }

    function lt(uint144 nx, uint112 dx, uint144 ny, uint112 dy) public pure returns (bool) {
        FixedPoint.uq144x112 memory x = FixedPoint.fraction144(nx, dx);
        FixedPoint.uq144x112 memory y = FixedPoint.fraction144(ny, dy);
        return x.lt(y);
    }

    function gt(uint144 nx, uint112 dx, uint144 ny, uint112 dy) public pure returns (bool) {
        FixedPoint.uq144x112 memory x = FixedPoint.fraction144(nx, dx);
        FixedPoint.uq144x112 memory y = FixedPoint.fraction144(ny, dy);
        return x.gt(y);
    }

    function pow(uint144 numerator, uint112 denominator, uint256 n) public pure returns (uint144) {
        FixedPoint.uq144x112 memory b = FixedPoint.fraction144(numerator, denominator);
        return FixedPoint.pow(b, n).decode144();
    }

    function compound(uint256 principal, uint112 numerator, uint112 denominator, uint256 n) public pure returns (uint144) {
        FixedPoint.uq144x112 memory b = FixedPoint.fraction144(numerator, denominator);
        return FixedPoint.pow(b, n).mul(principal).decode144();
    }
}
