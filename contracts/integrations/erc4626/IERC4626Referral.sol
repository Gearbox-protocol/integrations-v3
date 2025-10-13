// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IERC4626Referral {
    function deposit(uint256 assets, address receiver, uint16 referral) external returns (uint256 shares);
    function mint(uint256 shares, address receiver, uint16 referral) external returns (uint256 assets);
}
