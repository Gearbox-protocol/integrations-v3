// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IMellowWrapper {
    function deposit(address depositToken, uint256 amount, address vault, address receiver, address referral)
        external
        returns (uint256 shares);

    function WETH() external view returns (address);
}
