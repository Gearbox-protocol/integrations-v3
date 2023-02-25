// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { IAdapter } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

/// @title Aave V2 LendingPool adapter interface
interface IAaveV2_LendingPoolAdapter is IAdapter {
    /// @notice Deposit underlying tokens into Aave in exchange for aTokens
    /// @param asset Address of underlying token to deposit
    /// @param amount Amount of underlying tokens to deposit
    /// @dev Last two parameters are ignored as `onBehalfOf` can only be credit account,
    ///      and `referralCode` is set to zero
    function deposit(address asset, uint256 amount, address, uint16) external;

    /// @notice Deposit all underlying tokens into Aave in exchange for aTokens, disables underlying
    /// @param asset Address of underlying token to deposit
    function depositAll(address asset) external;

    /// @notice Withdraw underlying tokens from Aave and burn aTokens
    /// @param asset Address of underlying token to deposit
    /// @param amount Amount of underlying tokens to withdraw
    ///        If `type(uint256).max`, will withdraw the full amount
    /// @dev Last parameter is ignored because underlying recepient can only be credit account
    function withdraw(address asset, uint256 amount, address) external;

    /// @notice Withdraw all underlying tokens from Aave and burn aTokens, disables aToken
    /// @param asset Address of underlying token to withdraw
    function withdrawAll(address asset) external;
}
