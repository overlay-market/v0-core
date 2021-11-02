// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../OverlayV1UniswapV3Market.sol";
import "../libraries/FixedPoint.sol";

contract OverlayV1UniswapV3MarketZeroLambdaShim is OverlayV1UniswapV3Market {

    using FixedPoint for uint256;

    constructor(
        address _mothership,
        address _ovlFeed,
        address _marketFeed,
        address _quote,
        address _eth,
        uint128 _amountIn,
        uint256 _macroWindow,
        uint256 _microWindow
    ) OverlayV1UniswapV3Market (
        _mothership,
        _ovlFeed,
        _marketFeed,
        _quote,
        _eth,
        _amountIn,
        _macroWindow,
        _microWindow
    ) { }


    function _update (bool _readDepth) internal virtual override returns (uint cap_) {

        uint _brrrrdExpected = brrrrdExpected;
        uint _now = block.timestamp;
        uint _updated = updated;

        uint _depth;
        PricePoint memory _price;
        bool _readPrice = _now != _updated;

        if (_readDepth) {

            (   uint _brrrrd,
                uint _antiBrrrrd ) = getBrrrrd();

            bool _burnt;
            bool _expected;
            bool _surpassed;

            if (_brrrrd < _antiBrrrrd) _burnt = true;
            else {
                _brrrrd -= _antiBrrrrd;
                _expected = _brrrrd < _brrrrdExpected;
                _surpassed = _brrrrd < _brrrrdExpected * 2;
            }

            ( _price, _depth ) = readFeed(_readPrice, _burnt || _expected || _surpassed);
            
            _depth = staticCap;

            if (_readPrice) setPricePointNext(_price);

            if (_burnt || _expected) cap_ = Math.min(staticCap, _depth);

            else if (_surpassed) {
                uint _dynamicCap = ( 2e18 - _brrrrd.divDown(_brrrrdExpected) ).mulDown(staticCap);
                cap_ = Math.min(staticCap, Math.min(_dynamicCap, _depth));
            }


        } else if (_readPrice) {

            ( _price, ) = readFeed(true, false);

            setPricePointNext(_price);

        }

        (   uint _compoundings, 
            uint _tCompounding  ) = epochs(_now, compounded);

        if (0 < _compoundings) {

            payFunding(k, _compoundings);
            compounded = _tCompounding;

        }

    }

    function oiCap () public override view returns ( 
        uint cap_ 
    ) {

        (   uint _brrrrd, 
            uint _antiBrrrrd ) = getBrrrrd();

        uint _brrrrdExpected = brrrrdExpected;

        bool _burnt;
        bool _expected;
        bool _surpassed;

        if (_brrrrd < _antiBrrrrd) _burnt = true;
        else {
            _brrrrd -= _antiBrrrrd;
            _expected = _brrrrd < _brrrrdExpected;
            _surpassed = _brrrrd < _brrrrdExpected * 2;
        }

        ( ,uint _depth ) = readFeed(false, _burnt || _expected || _surpassed);

        _depth = staticCap; // shim the static cap value;

        if (_surpassed) {

            uint _dynamicCap = ( 2e18 - _brrrrd.divDown(_brrrrdExpected) ).mulDown(staticCap);
            cap_ = Math.min(staticCap, Math.min(_dynamicCap, _depth));

        } else if (_burnt || _expected) cap_ = Math.min(staticCap, _depth);

    }


}