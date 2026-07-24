// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

uint256 constant MAX_PENDING_REDEEMERS_PER_ACCOUNT = 10;

bytes32 constant CREDIT_ACCOUNT_TYPE = "CREDIT_ACCOUNT";

/// @notice Access mode for a Midas gateway deployment
enum MidasMode {
    /// @dev No access control; any account may interact
    Permissionless,
    /// @dev Access-controlled vaults; credit accounts must belong to a market configurator,
    ///      but borrowers are not required to be greenlisted
    RestrictedInterface,
    /// @dev Access-controlled vaults; credit accounts must belong to a market configurator
    ///      and borrowers must be greenlisted
    Permissioned
}

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
    /// @dev Thrown when access-controlled issuance and redemption vaults use different access control contracts
    error IncompatibleAccessControlsException();
    /// @dev Thrown when a non-permissionless mode is configured but the Midas vaults have no access control
    error AccessControlNotSetException();
    /// @dev Thrown when attempting to create a new redeemer for an account that has too many pending redeemers
    error MaxPendingRedeemersPerAccountException();
    /// @dev Thrown when an account that is not eligible to interact with the gateway attempts to interact with the gateway
    error CreditAccountNotEligibleException();
    /// @dev Thrown when attempting to withdraw more tokens than all account's redeemers have
    error InsufficientBalanceException();
    /// @dev Thrown when attempting to create a gateway for a non-permissionless mode that allows arbitrary accounts
    ///      to interact with it
    error ArbitraryCAAllowedInPermissionedModeException();

    /// @notice Address of the mToken
    function mToken() external view returns (address);

    /// @notice Address of the quote token used for issuance and redemption
    function quoteToken() external view returns (address);

    /// @notice Address of the redemption phantom token
    function phantomToken() external view returns (address);

    /// @notice Address of the transfer master that can enable redeemer transfers (e.g. during liquidations)
    function transferMaster() external view returns (address);

    /// @notice Address of the Midas access control contract
    function accessControl() external view returns (address);

    /// @notice Access mode of the gateway
    function mode() external view returns (MidasMode);

    /// @notice Address of the redemption logger contract
    function redemptionLogger() external view returns (address);

    /// @notice Performs instant issuance of mToken for quote token
    /// @param amountToken Amount of quote token to deposit
    /// @param minReceiveAmount Minimum amount of mToken to receive
    /// @param referrerId Referrer ID
    function depositInstant(uint256 amountToken, uint256 minReceiveAmount, bytes32 referrerId) external;

    /// @notice Performs instant redemption of mToken for quote token
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param minReceiveAmount Minimum amount of quote token to receive
    function redeemInstant(uint256 amountMTokenIn, uint256 minReceiveAmount) external;

    /// @notice Requests a redemption of mToken for quote token
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param extraData Additional redemption data to log
    function requestRedeem(uint256 amountMTokenIn, bytes calldata extraData) external;

    /// @notice Withdraws tokens from fulfilled redemption requests
    /// @param amount Amount of quote token to withdraw
    function withdraw(uint256 amount) external;

    /// @notice Withdraws tokens from a specific redeemer
    /// @param redeemer The redeemer to withdraw from
    /// @param amount The amount to withdraw
    function withdrawFromRedeemer(address redeemer, uint256 amount) external;

    /// @notice Transfers a redeemer to a new account
    /// @param redeemer The redeemer to transfer
    /// @param newAccount The new account to transfer the redeemer to
    function transferRedeemer(address redeemer, address newAccount) external;

    /// @notice Returns the pending and claimable amounts of quote token for an account, across all counted redeemers
    /// @param account Account to check
    /// @return pendingAmount Pending amount of quote token
    /// @return claimableAmount Claimable amount of quote token
    function pendingAndClaimableTokenOutAmounts(address account)
        external
        view
        returns (uint256 pendingAmount, uint256 claimableAmount);

    /// @notice Returns the pending redeemers for an account
    /// @param account The account to check
    /// @return redeemers The pending redeemers for the account
    function pendingRedeemers(address account) external view returns (address[] memory redeemers);
}
