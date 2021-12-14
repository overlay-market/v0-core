// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./collateral/MarketCodex.sol";

contract Scratchpad {

    using MarketCodexTest for bytes32;

    uint256 private constant _MASK_1 = 2**(1) - 1;
    uint256 private constant _MASK_5 = 2**(5) - 1;
    uint256 private constant _MASK_7 = 2**(7) - 1;
    uint256 private constant _MASK_10 = 2**(10) - 1;
    uint256 private constant _MASK_16 = 2**(16) - 1;
    uint256 private constant _MASK_20 = 2**(20) - 1;
    uint256 private constant _MASK_22 = 2**(22) - 1;
    uint256 private constant _MASK_31 = 2**(31) - 1;
    uint256 private constant _MASK_32 = 2**(32) - 1;
    uint256 private constant _MASK_53 = 2**(53) - 1;
    uint256 private constant _MASK_64 = 2**(64) - 1;
    uint256 private constant _MASK_96 = 2**(96) - 1;
    uint256 private constant _MASK_128 = 2**(128) - 1;
    uint256 private constant _MASK_160 = 2**(160) - 1;
    uint256 private constant _MASK_192 = 2**(192) - 1;

    int256 private constant _MAX_INT_22 = 2**(21) - 1;
    int256 private constant _MAX_INT_53 = 2**(52) - 1;

    bytes32 codex;
    bytes16 smallCodex;

    constructor () { }

    function insertAddress () public {

        uint offset = 0;

        bytes32 clearedWord = bytes32(uint256(codex) & ~ (_MASK_160 << offset));

        codex = clearedWord | bytes32(uint256(uint160(address(this))) << offset);

    }

    function insertUint20s (
        uint256 _1,
        uint256 _2,
        uint256 _3,
        uint256 _4
    ) public {


        bytes32 clearedWord = bytes32(uint256(codex) & ~ (_MASK_20 << 236));

        codex = clearedWord | bytes32(_1 << 236);

        clearedWord = bytes32(uint256(codex) & ~ (_MASK_20 << 216));

        codex = clearedWord | bytes32(_2 << 216);

        clearedWord = bytes32(uint256(codex) & ~ (_MASK_20 << 196));

        codex = clearedWord | bytes32(_3 << 196);

        clearedWord = bytes32(uint256(codex) & ~ (_MASK_20 << 176));

        codex = clearedWord | bytes32(_4 << 176);

    }


    function setCodex (
        bool _active,
        uint _fee,
        uint _maxLev,
        uint _marginReward,
        uint _marginMaintenance
    ) public {

        codex = codex.set(
            address(this),
            _active,
            _fee,
            _maxLev,
            _marginReward,
            _marginMaintenance
        );

    }

    function getCodex () public view returns (
        address market_,
        bool active_,
        uint fee_,
        uint maxLev_,
        uint marginReward_,
        uint marginMaintenance_
    ) {

        (   market_,
            active_,
            fee_,
            maxLev_,
            marginReward_,
            marginMaintenance_ ) = codex.get();

    }

    function getMarginRewardRate () public view returns (
        uint marginMaintenance_
    ) {

        marginMaintenance_ = codex.getMarginRewardRate();

    }

    function getMarginMaintenance () public view returns (
        uint marginMaintenance_
    ) {

        marginMaintenance_ = codex.getMarginMaintenance();

    }


}


library MarketCodexTest {

    uint256 private constant UINT20_MASK = 2**(20)-1;
    uint256 private constant ADDRESS_MASK = 2**(160)-1;
    uint256 private constant BOOL_MASK = 2**(1)-1;
    
    //   [  address market, 
    //      bool active, 
    //      uint20 fee, 
    //      uint20 maxLeverage, 
    //      uint20 marginRewardRate, 
    //      uint20 marginMaintenance ]

    function set (
        bytes32 _codex,
        address _market,
        bool _active,
        uint _fee,
        uint _maxLeverage,
        uint _marginRewardRate,
        uint _marginMaintenance
    ) internal pure returns (
        bytes32 codex_
    ) {

        bytes32 _clear;

        _clear = bytes32(uint256(_codex) & ~ (ADDRESS_MASK << 0));
        _codex = _clear | bytes32(uint256(uint160(address(_market))) << 0);

        _clear = bytes32(uint256(_codex) & ~ (BOOL_MASK << 160));
        _codex = _clear | bytes32(uint256(_active ? 1 : 0) << 160);

        _clear = bytes32(uint256(_codex) & ~ (UINT20_MASK << 161));
        _codex = _clear | bytes32( (_fee/1e12) << 161);

        _clear = bytes32(uint256(_codex) & ~ (UINT20_MASK << 181));
        _codex = _clear | bytes32( (_maxLeverage/1e12) << 181);

        _clear = bytes32(uint256(_codex) & ~ (UINT20_MASK << 201));
        _codex = _clear | bytes32( (_marginRewardRate/1e12) << 201);

        _clear = bytes32(uint256(_codex) & ~ (UINT20_MASK << 221));
        _codex = _clear | bytes32( (_marginMaintenance/1e12) << 221);

        codex_ = _codex;

    }

    function setActive (
        bytes32 _codex,
        bool _active
    ) internal pure returns (
        bytes32 codex_
    ) {

        bytes32 _clearCodex = bytes32(uint256(_codex) & ~ (BOOL_MASK << 160));

        codex_ = _clearCodex | bytes32(uint256(_active ? 1 : 0) << 160);

    }
    
    function setFee (
        bytes32 _codex,
        uint _fee
    ) internal pure returns (
        bytes32 codex_
    ) {

        bytes32 _clearCodex = bytes32(uint256(_codex) & ~ (UINT20_MASK << 181));

        codex_ = _clearCodex | bytes32((_fee/1e12) << 181);

    }

    function setMaxLeverage (
        bytes32 _codex,
        uint _maxLeverage
    ) internal pure returns (
        bytes32 codex_
    ) {

        bytes32 _clearCodex = bytes32(uint256(_codex) & ~ (UINT20_MASK << 201));

        codex_ = _clearCodex | bytes32((_maxLeverage/1e12) << 201);

    }

    function setMarginRewardRate (
        bytes32 _codex,
        uint _marginRewardRate
    ) internal pure returns (
        bytes32 codex_
    ) {

        bytes32 _clearCodex = bytes32(uint256(_codex) & ~ (UINT20_MASK << 221));

        codex_ = _clearCodex | bytes32((_marginRewardRate/1e12) << 221);
    
    }

    function setMarginMaintenance (
        bytes32 _codex,
        uint _marginMaintenance
    ) internal pure returns (
        bytes32 codex_
    ) {

        bytes32 _clearCodex = bytes32(uint256(_codex) & ~ (UINT20_MASK << 241));

        codex_ = _clearCodex | bytes32((_marginMaintenance/1e12) << 241);

    }


    function get (bytes32 _codex) internal pure returns (
        address market_,
        bool active_,
        uint fee_,
        uint maxLeverage_,
        uint marginRewardRate_,
        uint marginMaintenance_
    ) {

        market_ = address(uint160(uint256(_codex >> 0) & ADDRESS_MASK));

        active_ = ( uint256(_codex >> 160) & BOOL_MASK) == 1;

        fee_ = 1e12 * ( uint256(_codex >> 161 ) & UINT20_MASK );

        maxLeverage_ = 1e12 * ( uint256(_codex >> 181) & UINT20_MASK );

        marginRewardRate_ = 1e12 * ( uint256(_codex >> 201) & UINT20_MASK );

        marginMaintenance_ = 1e12 * ( uint256(_codex >> 221) & UINT20_MASK );

    }

    function getMarket (
        bytes32 _codex
    ) internal pure returns (
        address market_
    ) {

        market_ = address(uint160(uint256(_codex >> 0) & ADDRESS_MASK));

    }

    function getActive (
        bytes32 _codex
    ) internal pure returns (
        bool active_
    ) { 

        active_ = (uint256(_codex >> 161) & BOOL_MASK) == 1;

    }

    function getFee (
        bytes32 _codex
    ) internal pure returns (
        uint fee_
    ) {

        fee_ = 1e12 * uint256(_codex >> 181 ) & UINT20_MASK;

    }

    function getMaxLeverage (
        bytes32 _codex
    ) internal pure returns (
        uint maxLeverage_
    ) {

        maxLeverage_ = 1e12 * uint256(_codex >> 201) & UINT20_MASK;

    }
    
    function getMarginRewardRate (
        bytes32 _codex
    ) internal pure returns (
        uint marginRewardRate_
    ) {

        marginRewardRate_ = 1e12 * ( uint256(_codex >> 221) & UINT20_MASK );

    }

    function getMarginMaintenance (
        bytes32 _codex
    ) internal pure returns (
        uint marginMaintenance_
    ) {

        marginMaintenance_ = uint256(_codex >> 241) & UINT20_MASK;

    }

}