// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

/// @notice Status update for an allowed underlying asset
struct AaveV3AssetStatus {
    address asset;
    bool allowed;
}

/// @title Aave V3 Pool adapter interface
/// @notice Allows Credit Accounts to supply and withdraw on an Aave V3 Pool
interface IAaveV3PoolAdapter is IAdapter {
    /// @notice Emitted when an underlying asset is allowed / disallowed
    event SetAssetStatus(address indexed asset, bool allowed);

    /// @notice Aave V3 Pool (same as `targetContract`)
    function pool() external view returns (address);

    /// @notice Integrator referral code passed to Aave `supply`
    function referralCode() external view returns (uint16);

    /// @notice Whether `asset` is allowed for supply / withdraw
    function isAssetAllowed(address asset) external view returns (bool);

    /// @notice List of allowed underlying assets
    function allowedAssets() external view returns (address[] memory);

    /// @notice Supplies underlying from the credit account in exchange for aTokens
    /// @param asset Underlying asset to supply
    /// @param amount Amount to supply
    /// @dev `onBehalfOf` and the Pool's referral arg are ignored; onBehalfOf is always the CA
    function supply(address asset, uint256 amount, address, uint16) external returns (bool useSafePrices);

    /// @notice Supplies the entire underlying balance except `leftoverAmount`
    /// @param asset Underlying asset to supply
    /// @param leftoverAmount Amount of underlying to keep on the credit account
    function supplyDiff(address asset, uint256 leftoverAmount) external returns (bool useSafePrices);

    /// @notice Withdraws underlying to the credit account by burning aTokens
    /// @param asset Underlying asset to withdraw
    /// @param amount Amount of underlying to withdraw
    /// @dev `to` is ignored; recipient is always the credit account
    function withdraw(address asset, uint256 amount, address) external returns (bool useSafePrices);

    /// @notice Withdraws by burning all aTokens except `leftoverAmount`
    /// @param asset Underlying asset to withdraw
    /// @param leftoverAmount Amount of aTokens to keep on the credit account
    function withdrawDiff(address asset, uint256 leftoverAmount) external returns (bool useSafePrices);

    /// @notice Allows / disallows a batch of underlying assets
    function setAssetStatusBatch(AaveV3AssetStatus[] calldata assets) external;
}
