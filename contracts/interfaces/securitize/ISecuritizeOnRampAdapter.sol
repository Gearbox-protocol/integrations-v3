// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

/// @title Securitize On-Ramp adapter interface
interface ISecuritizeOnRampAdapter is IAdapter {
    /// @notice DS token minted by the on-ramp
    function dsToken() external view returns (address);

    /// @notice Stablecoin (liquidity token) spent in the on-ramp
    function stableCoinToken() external view returns (address);

    /// @notice Performs an exact-in swap on the on-ramp
    /// @param liquidityAmount Amount of stablecoin to spend
    /// @param minOutAmount Minimum acceptable amount of DS tokens
    /// @return success Always true if call did not revert
    function swap(uint256 liquidityAmount, uint256 minOutAmount) external returns (bool success);

    /// @notice Swaps the entire balance of stablecoin on the credit account,
    ///         except for the specified leftover amount, while enforcing
    ///         a minimum exchange rate between input and output tokens.
    /// @param leftoverAmount Amount of stablecoin to keep on the account
    /// @param rateMinRAY Minimum acceptable rate (dsToken per stablecoin), scaled by 1e27
    /// @return success False if there is not enough balance to perform the swap
    function swapDiff(uint256 leftoverAmount, uint256 rateMinRAY) external returns (bool success);
}

