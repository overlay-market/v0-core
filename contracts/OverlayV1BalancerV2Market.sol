// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./libraries/FixedPoint.sol";
import "./libraries/UniswapV3OracleLibrary/TickMath.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./market/OverlayV1Market.sol";

contract OverlayV1BalancerV2Market is OverlayV1Market {

    using FixedPoint for uint256;

    uint256 internal X96 = 0x1000000000000000000000000;

    uint256 public immutable macroWindow; // window size for main TWAP
    uint256 public immutable microWindow; // window size for bid/ask TWAP

    address public immutable marketFeed;
    address public immutable ovlFeed;
    address public immutable base;
    address public immutable quote;
    uint128 internal immutable baseAmount;

    address internal immutable eth;
    bool internal immutable ethIs0;

    constructor(
        address _mothership,
        address _ovlFeed,
        address _marketFeed,
        address _quote,
        address _eth,
        uint128 _baseAmount,
        uint256 _macroWindow,
        uint256 _microWindow,
        uint256 _priceFrameCap
    ) OverlayV1Market (
        _mothership
    ) OverlayV1Comptroller (
        _microWindow
    ) OverlayV1OI (
        _microWindow
    ) OverlayV1PricePoint (
        _priceFrameCap
    ) {

        // immutables
        eth = _eth;
        ethIs0 = false;
        ovlFeed = _ovlFeed;
        marketFeed = _marketFeed;
        baseAmount = _baseAmount;
        macroWindow = _macroWindow;
        microWindow = _microWindow;

        // TODO: just to compile for now.
        base = _quote;
        quote = _quote;

    }


    /// @notice Reads the current price and depth information
    /// @dev Reads price and depth of market feed
    /// @return price_ Price point
    function fetchPricePoint () public view override returns (
        PricePoint memory price_
    ) { }


    /// @notice Arithmetic to get depth
    /// @dev Derived from cnstant product formula X*Y=K and tailored 
    /// to Uniswap V3 selective liquidity provision.
    /// @param _marketLiquidity Amount of liquidity in market in ETH terms.
    /// @param _ovlPrice Price of OVL against ETH.
    /// @return depth_ Depth criteria for market in OVL terms.
    function computeDepth (
        uint _marketLiquidity,
        uint _ovlPrice
    ) public override view returns (
        uint depth_
    ) {

        depth_ = ((_marketLiquidity * 1e18) / _ovlPrice)
            .mulUp(lmbda)    
            .divDown(2e18);

    }

    function _tickToPrice (
        int24 _tick
    ) public override view returns (
        uint quote_
    ) { }

}
