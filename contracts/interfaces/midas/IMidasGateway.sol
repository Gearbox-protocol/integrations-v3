// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

uint256 constant MAX_PENDING_REDEEMERS_PER_ACCOUNT = 10;

bytes32 constant CREDIT_ACCOUNT_TYPE = "CREDIT_ACCOUNT";

/// @title Midas Gateway interface
/// @notice External interface of the unified Midas gateway that manages both issuances and redemptions
interface IMidasGateway is IVersion {
    /// @dev Thrown when attempting to transfer a redeemer to a new account without permission
    error RedeemerTransferNotAllowedException();
    /// @dev Thrown when attempting to transfer a redeemer to a new account that is not greenlisted
    error NewAccountNotGreenlistedException();
    /// @dev Thrown when a non-owner attempts to manage a redeemer
    error RedeemerNotOwnedByAccountException();
    /// @dev Thrown when attempting to instantiate a gateway with issuance and redemption vaults that have different mTokens
    error IncompatibleIssuanceAndRedemptionVaultsException();
    /// @dev Thrown when attempting to instantiate a greenlist-only gateway without setting the access control
    error AccessControlNotSetException();
    /// @dev Thrown when attempting to create a new redeemer for an account that has too many pending redeemers
    error MaxPendingRedeemersPerAccountException();
    /// @dev Thrown when an account that is not eligible to interact with the gateway attempts to interact with the gateway
    error CreditAccountNotEligibleException();
    /// @dev Thrown when attempting to withdraw more tokens than all account's redeemers have
    error InsufficientBalanceException();

    /// @notice Address of the mToken
    function mToken() external view returns (address);

    /// @notice Address of the transfer master that can enable redeemer transfers (e.g. during liquidations)
    function transferMaster() external view returns (address);

    /// @notice Address of the Midas access control contract
    function accessControl() external view returns (address);

    /// @notice Performs instant issuance of mToken for input token
    /// @param tokenIn Input token to deposit
    /// @param amountToken Amount of input token to deposit
    /// @param minReceiveAmount Minimum amount of mToken to receive
    /// @param referrerId Referrer ID
    function depositInstant(address tokenIn, uint256 amountToken, uint256 minReceiveAmount, bytes32 referrerId) external;

    /// @notice Performs instant redemption of mToken for output token
    /// @param tokenOut Output token to receive
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param minReceiveAmount Minimum amount of output token to receive
    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount) external;

    /// @notice Requests a redemption of mToken for output token
    /// @param tokenOut Output token to receive
    /// @param amountMTokenIn Amount of mToken to redeem
    function requestRedeem(address tokenOut, uint256 amountMTokenIn) external;

    /// @notice Withdraws tokens from fulfilled redemption requests
    /// @param tokenOut Output token to withdraw
    /// @param amount Amount of output token to withdraw
    function withdraw(address tokenOut, uint256 amount) external;

    /// @notice Withdraws tokens from a specific redeemer
    /// @param redeemer The redeemer to withdraw from
    /// @param tokenOut The token to withdraw
    /// @param amount The amount to withdraw
    function withdrawFromRedeemer(address redeemer, address tokenOut, uint256 amount) external;

    /// @notice Transfers a redeemer to a new account
    /// @param redeemer The redeemer to transfer
    /// @param newAccount The new account to transfer the redeemer to
    function transferRedeemer(address redeemer, address newAccount) external;

    /// @notice Returns the pending and claimable amounts of output token for an account, across all counted redeemers
    /// @param account Account to check
    /// @param tokenOut Output token to check
    /// @return pendingAmount Pending amount of output token
    /// @return claimableAmount Claimable amount of output token
    function pendingAndClaimableTokenOutAmounts(address account, address tokenOut)
        external
        view
        returns (uint256 pendingAmount, uint256 claimableAmount);

    /// @notice Returns the pending redeemers for an account
    /// @param account The account to check
    /// @return redeemers The pending redeemers for the account
    function pendingRedeemers(address account) external view returns (address[] memory redeemers);
}
