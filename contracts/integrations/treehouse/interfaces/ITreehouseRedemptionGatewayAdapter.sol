// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IPhantomTokenAdapter} from "../../common/interfaces/IPhantomTokenAdapter.sol";

/// @title Treehouse Redemption Gateway adapter interface
interface ITreehouseRedemptionGatewayAdapter is IPhantomTokenAdapter {
    /// @notice Address of the TAsset contract
    function tAsset() external view returns (address);

    /// @notice Address of the underlying token of the vault
    function vaultUnderlying() external view returns (address);

    /// @notice Address of the redemption phantom token
    function phantomToken() external view returns (address);

    /// @notice Initiates a redemption for a specific TAsset amount
    /// @param shares The amount of TAsset shares to redeem
    function redeem(uint256 shares) external returns (bool);

    /// @notice Initiates a redemption for a specific TAsset amount with extra data
    /// @param shares The amount of TAsset shares to redeem
    /// @param extraData Additional data to include in the redemption
    function redeem(uint256 shares, bytes calldata extraData) external returns (bool);

    /// @notice Initiates a redemption for the entire TAsset balance, except the specified amount
    /// @param leftoverShares The amount of TAsset shares to leave on the account
    function redeemDiff(uint256 leftoverShares) external returns (bool);

    /// @notice Initiates a redemption for the entire TAsset balance, except the specified amount, with extra data
    /// @param leftoverShares The amount of TAsset shares to leave on the account
    /// @param extraData Additional data to include in the redemption
    function redeemDiff(uint256 leftoverShares, bytes calldata extraData) external returns (bool);

    /// @notice Finalizes a mature redemption for a specific redeemer
    /// @param redeemer The redeemer to finalize
    function finalizeRedeem(address redeemer) external returns (bool);

    /// @notice Transfers a redeemer to a new account
    /// @param redeemer The redeemer to transfer
    /// @param newAccount The new account to transfer the redeemer to
    function transferRedeemer(address redeemer, address newAccount) external returns (bool);
}
