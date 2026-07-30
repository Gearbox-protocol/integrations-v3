// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {IPhantomTokenAdapter} from "../../common/interfaces/IPhantomTokenAdapter.sol";

/// @title Midas Gateway adapter interface
/// @notice Delayed-redemption adapter for the Midas gateway
interface IMidasGatewayAdapter is IAdapter, IPhantomTokenAdapter {
    error PhantomTokenNotSetException();

    /// @notice Address of mToken
    function mToken() external view returns (address);

    /// @notice Address of the gateway
    function gateway() external view returns (address);

    /// @notice Address of the quote token used for redemption
    function quoteToken() external view returns (address);

    /// @notice Address of the redemption phantom token
    function phantomToken() external view returns (address);

    /// @notice Grants the greenlisted role to the credit account via the gateway
    function receiveGreenlist() external returns (bool);

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

    /// @notice Transfers a redeemer to a new account
    /// @param redeemer The redeemer to transfer
    /// @param newAccount The new account to transfer the redeemer to
    function transferRedeemer(address redeemer, address newAccount) external returns (bool);
}
