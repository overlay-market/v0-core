// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IOverlayFactory {
    function isMarket(address) external view returns (bool);
    function getGlobalParams() external view returns (uint16, uint16, uint16, uint16, address, uint8, uint8, uint8, address);
    function updateMarket(address, address) external;
    function massUpdateMarkets(address) external;
}
