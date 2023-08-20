// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";

/// @title wstETH adapter interface
/// @notice Implements logic for wrapping / unwrapping stETH
interface IwstETHV1Adapter is IAdapter {
    /// @notice Address of the Lido contract
    function stETH() external view returns (address);

    /// @notice Collateral token mask of stETH in the credit manager
    function stETHTokenMask() external view returns (uint256);

    /// @notice Collateral token mask of wstETH in the credit manager
    function wstETHTokenMask() external view returns (uint256);

    /// @notice Wraps given amount of stETH into wstETH
    /// @param amount Amount of stETH to wrap
    function wrap(uint256 amount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    /// @notice Wraps the entire balance of stETH into wstETH, disables stETH
    function wrapAll() external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    /// @notice Unwraps given amount of wstETH into stETH
    /// @param amount Amount of wstETH to unwrap
    function unwrap(uint256 amount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    /// @notice Unwraps the entire balance of wstETH to stETH, disables wstETH
    function unwrapAll() external returns (uint256 tokensToEnable, uint256 tokensToDisable);
}
