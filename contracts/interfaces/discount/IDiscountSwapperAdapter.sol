// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {IDiscountSwapper} from "./IDiscountSwapper.sol";

/// @title DiscountSwapper Adapter Interface
/// @notice Interface for the adapter to interact with DiscountSwapper contract
interface IDiscountSwapperAdapter is IAdapter {
    /// @notice Swaps assetIn for assetOut based on the defined exchange rate
    /// @param assetIn The asset to send to the treasury
    /// @param assetOut The asset to receive from the treasury
    /// @param amountIn The amount of assetIn to swap
    /// @return amountOut The amount of assetOut received
    function swap(address assetIn, address assetOut, uint256 amountIn) external returns (bool);

    /// @notice Swaps all available assetIn for assetOut, except for a specified leftover amount
    /// @param assetIn The asset to send to the treasury
    /// @param assetOut The asset to receive from the treasury
    /// @param leftoverAmount The amount of assetIn to keep in the credit account
    /// @return amountOut The amount of assetOut received
    function swapDiff(address assetIn, address assetOut, uint256 leftoverAmount) external returns (bool);
}
