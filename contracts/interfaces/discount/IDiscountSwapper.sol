// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

interface IDiscountSwapperExceptions {
    error MarketConfiguratorNotAllowedException();
}

interface IDiscountSwapperEvents {
    event SetExchangeRate(address indexed asset0, address indexed asset1, uint256 rate);
    event SetMarketConfiguratorStatus(address indexed marketConfigurator, bool allowed);
    event SwapAsset(
        address indexed asset0, address indexed asset1, uint256 amount0, uint256 amount1, address indexed user
    );
}

/// @title Discount Swapper Interface
/// @notice Interface for the contract that allows the treasury to define exchange rates between assets and facilitate swaps
interface IDiscountSwapper is IVersion, IDiscountSwapperEvents, IDiscountSwapperExceptions {
    /// @notice Sets the exchange rate between two assets
    /// @param assetIn The first asset in the pair (source)
    /// @param assetOut The second asset in the pair (destination)
    /// @param rate The exchange rate (assetOut/assetIn), scaled by RATE_PRECISION
    function setExchangeRate(address assetIn, address assetOut, uint256 rate) external;

    /// @notice Swaps assetIn for assetOut based on the defined exchange rate
    /// @param assetIn The asset to send to the treasury
    /// @param assetOut The asset to receive from the treasury
    /// @param amountIn The amount of assetIn to swap
    /// @return amountOut The amount of assetOut received
    function swap(address assetIn, address assetOut, uint256 amountIn) external returns (uint256 amountOut);

    /// @notice Gets the exchange rate between two assets
    /// @param assetIn The first asset in the pair (source)
    /// @param assetOut The second asset in the pair (destination)
    /// @return The exchange rate (assetOut/assetIn), scaled by RATE_PRECISION
    function exchangeRates(address assetIn, address assetOut) external view returns (uint256);
}
