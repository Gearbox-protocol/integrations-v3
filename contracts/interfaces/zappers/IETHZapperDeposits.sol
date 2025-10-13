// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

/// @dev Special address that denotes pure ETH
address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

interface IETHZapperDeposits {
    function deposit(address receiver) external payable returns (uint256 tokenOutAmount);

    function depositWithReferral(address receiver, uint256 referralCode)
        external
        payable
        returns (uint256 tokenOutAmount);
}
