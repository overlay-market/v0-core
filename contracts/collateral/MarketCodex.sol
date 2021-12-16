// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

library MarketCodex {

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
        _codex = _clear | bytes32( (_maxLeverage/1e16) << 181);

        _clear = bytes32(uint256(_codex) & ~ (UINT20_MASK << 201));
        _codex = _clear | bytes32( (_marginRewardRate/1e12) << 201);

        _clear = bytes32(uint256(_codex) & ~ (UINT20_MASK << 221));
        codex_ = _clear | bytes32( (_marginMaintenance/1e12) << 221);

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

        bytes32 _clearCodex = bytes32(uint256(_codex) & ~ (UINT20_MASK << 161));

        codex_ = _clearCodex | bytes32((_fee / 1e12) << 161);

    }

    function setMaxLeverage (
        bytes32 _codex,
        uint _maxLeverage
    ) internal pure returns (
        bytes32 codex_
    ) {

        bytes32 _clearCodex = bytes32(uint256(_codex) & ~ (UINT20_MASK << 181));

        codex_ = _clearCodex | bytes32((_maxLeverage / 1e16) << 181);

    }

    function setMarginRewardRate (
        bytes32 _codex,
        uint _marginRewardRate
    ) internal pure returns (
        bytes32 codex_
    ) {

        bytes32 _clearCodex = bytes32(uint256(_codex) & ~ (UINT20_MASK << 201));

        codex_ = _clearCodex | bytes32((_marginRewardRate / 1e12) << 201);
    
    }

    function setMarginMaintenance (
        bytes32 _codex,
        uint _marginMaintenance
    ) internal pure returns (
        bytes32 codex_
    ) {

        bytes32 _clearCodex = bytes32(uint256(_codex) & ~ (UINT20_MASK << 221));

        codex_ = _clearCodex | bytes32((_marginMaintenance / 1e12) << 221);

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

        active_ = (uint256(_codex >> 160) & BOOL_MASK) == 1;

        fee_ = 1e12 * ( uint256(_codex >> 161 ) & UINT20_MASK );

        maxLeverage_ = 1e16 * ( uint256(_codex >> 181) & UINT20_MASK );

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

        active_ = ( uint256(_codex >> 160) & BOOL_MASK ) == 1;

    }

    function getFee (
        bytes32 _codex
    ) internal pure returns (
        uint fee_
    ) {

        fee_ = 1e12 * ( uint256(_codex >> 161 ) & UINT20_MASK );

    }

    function getMaxLeverage (
        bytes32 _codex
    ) internal pure returns (
        uint maxLeverage_
    ) {

        maxLeverage_ = 1e16 * ( uint256(_codex >> 181) & UINT20_MASK );

    }
    
    function getMarginRewardRate (
        bytes32 _codex
    ) internal pure returns (
        uint marginRewardRate_
    ) {

        marginRewardRate_ = 1e12 * ( uint256(_codex >> 201) & UINT20_MASK );

    }

    function getMarginMaintenance (
        bytes32 _codex
    ) internal pure returns (
        uint marginMaintenance_
    ) {

        marginMaintenance_ = 1e12 * ( uint256(_codex >> 221) & UINT20_MASK );

    }

}