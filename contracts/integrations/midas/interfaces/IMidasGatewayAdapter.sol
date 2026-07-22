// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {IPhantomTokenAdapter} from "../../common/interfaces/IPhantomTokenAdapter.sol";

/// @title Midas Gateway adapter interface
/// @notice Combines the issuance and redemption scope of the standalone Midas adapters behind a single gateway
interface IMidasGatewayAdapter is IAdapter, IPhantomTokenAdapter {
    error PhantomTokenNotSetException();

    // -------- //
    // GENERAL  //
    // -------- //

    /// @notice Address of mToken
    function mToken() external view returns (address);

    /// @notice Address of the gateway
    function gateway() external view returns (address);

    /// @notice Address of the quote token used for issuance and redemption
    function quoteToken() external view returns (address);

    /// @notice Address of the redemption phantom token
    function phantomToken() external view returns (address);

    /// @notice Referrer ID used for issuances
    function referrerId() external view returns (bytes32);

    // -------- //
    // ISSUANCE //
    // -------- //

    /// @notice Deposits specified amount of quote token for mToken
    /// @param amountToken Amount of quote token to deposit
    /// @param minReceiveAmount Minimum amount of mToken to receive
    function depositInstant(uint256 amountToken, uint256 minReceiveAmount, bytes32) external returns (bool);

    /// @notice Deposits entire balance of quote token, except the specified amount
    /// @param leftoverAmount Amount of quote token to keep in the account
    /// @param rateMinRAY Minimum exchange rate from quote token to mToken (in RAY format)
    function depositInstantDiff(uint256 leftoverAmount, uint256 rateMinRAY) external returns (bool);

    // ---------- //
    // REDEMPTION //
    // ---------- //

    /// @notice Instantly redeems mToken for quote token
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param minReceiveAmount Minimum amount of quote token to receive
    function redeemInstant(uint256 amountMTokenIn, uint256 minReceiveAmount) external returns (bool);

    /// @notice Instantly redeems mToken for quote token, with a leftover amount
    /// @param leftoverAmount Amount of mToken to keep in the account
    /// @param rateMinRAY Minimum exchange rate from mToken to quote token (in RAY format)
    function redeemInstantDiff(uint256 leftoverAmount, uint256 rateMinRAY) external returns (bool);

    /// @notice Requests a redemption of mToken for quote token
    /// @param amountMTokenIn Amount of mToken to redeem
    function redeemRequest(uint256 amountMTokenIn) external returns (bool);

    /// @notice Requests a redemption of mToken for quote token with extra logging data
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param extraData Additional redemption data to log
    function redeemRequest(uint256 amountMTokenIn, bytes calldata extraData) external returns (bool);

    /// @notice Requests a redemption of the entire mToken balance, except the specified amount
    /// @param leftoverAmount Amount of mToken to keep in the account
    function redeemRequestDiff(uint256 leftoverAmount) external returns (bool);

    /// @notice Requests a redemption of the entire mToken balance, except the specified amount
    /// @param leftoverAmount Amount of mToken to keep in the account
    /// @param extraData Additional redemption data to log
    function redeemRequestDiff(uint256 leftoverAmount, bytes calldata extraData) external returns (bool);

    /// @notice Withdraws redeemed tokens from the gateway
    /// @param amount Amount to withdraw
    function withdraw(uint256 amount) external returns (bool);

    /// @notice Withdraws tokens from a specific redeemer
    /// @param redeemer The redeemer to withdraw from
    /// @param amount The amount to withdraw
    function withdrawFromRedeemer(address redeemer, uint256 amount) external returns (bool);

    // ----------------- //
    // TRANSFER REDEEMER //
    // ----------------- //

    /// @notice Transfers a redeemer to a new account
    /// @param redeemer The redeemer to transfer
    /// @param newAccount The new account to transfer the redeemer to
    function transferRedeemer(address redeemer, address newAccount) external returns (bool);
}
