// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

/// @title Aave V2 Wrapped aToken adapter interface
interface IAaveV2_WrappedATokenAdapter is IAdapter {
    /// @notice Underlying aToken
    function aToken() external view returns (address);

    /// @notice Underlying token
    function underlying() external view returns (address);

    /// @notice Deposit given amount of aTokens
    /// @param assets Amount of aTokens to deposit in exchange for waTokens
    function deposit(uint256 assets) external;

    /// @notice Deposit all balance of aTokens
    function depositAll() external;

    /// @notice Deposit given amount underlying tokens
    /// @param assets Amount of underlying tokens to deposit in exchange for waTokens
    function depositUnderlying(uint256 assets) external;

    /// @notice Deposit all balance of underlying tokens
    function depositAllUnderlying() external;

    /// @notice Withdraw given amount of waTokens for aTokens
    /// @param shares Amount of waTokens to burn in exchange for aTokens
    function withdraw(uint256 shares) external;

    /// @notice Withdraw all balance of waTokens for aTokens
    function withdrawAll() external;

    /// @notice Withdraw given amount of waTokens for underlying tokens
    /// @param shares Amount of waTokens to burn in exchange for underlying tokens
    function withdrawUnderlying(uint256 shares) external;

    /// @notice Withdraw all balance of waTokens for underlying tokens
    function withdrawAllUnderlying() external;
}
