// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IDaiUsds {
    function daiToUsds(address usr, uint256 wad) external;

    function usdsToDai(address usr, uint256 wad) external;

    function dai() external view returns (address);

    function usds() external view returns (address);
}
