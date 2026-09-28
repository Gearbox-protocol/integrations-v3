// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {ICAChecker} from "../../common/interfaces/ICAChecker.sol";
import {IRedemptionLogging} from "../../common/interfaces/IRedemptionLogging.sol";

/// @dev Bounds the loops that iterate an account's pending redeemers, `withdraw` above all
uint256 constant MAX_PENDING_REDEEMERS_PER_ACCOUNT = 10;

/// @notice Access mode for a Midas gateway deployment
enum MidasMode {
    /// @dev No Midas access control; credit accounts from the allowed market configurator may interact
    Permissionless,
    /// @dev Access-controlled vaults; credit accounts must belong to a market configurator,
    ///      but borrowers are not required to be greenlisted
    RestrictedInterface,
    /// @dev Access-controlled vaults; credit accounts must belong to a market configurator
    ///      and borrowers must be greenlisted
    Permissioned
}

/// @title Midas Gateway interface
/// @notice External interface of the Midas delayed-redemption gateway
interface IMidasGateway is IVersion, ICAChecker, IRedemptionLogging {
    /// @dev Thrown when attempting to transfer a redeemer to a new account without permission
    error RedeemerTransferNotAllowedException();
    /// @dev Thrown when attempting to transfer a redeemer to a new account that is not greenlisted
    error NewAccountNotGreenlistedException();
    /// @dev Thrown when a non-owner attempts to manage a redeemer
    error RedeemerNotOwnedByAccountException();
    /// @dev Thrown when a non-permissionless mode is configured but the Midas vault has no access control
    error AccessControlNotSetException();
    /// @dev Thrown when attempting to create a new redeemer for an account that has too many pending redeemers
    error MaxPendingRedeemersPerAccountException();
    /// @dev Thrown when attempting to withdraw more tokens than all account's redeemers have
    error InsufficientBalanceException();
    /// @dev Thrown when attempting to request a greenlist in a non-permissioned mode
    error GreenlistRequestedInNonPermissionedModeException();

    /// @notice Address of the mToken
    function mToken() external view returns (address);

    /// @notice Address of the quote token used for redemption
    function quoteToken() external view returns (address);

    /// @notice Address of the redemption phantom token
    function phantomToken() external view returns (address);

    /// @notice Address of the transfer master that can enable redeemer transfers (e.g. during liquidations)
    function transferMaster() external view returns (address);

    /// @notice Address of the Midas access control contract
    function accessControl() external view returns (address);

    /// @notice Access mode of the gateway
    function mode() external view returns (MidasMode);

    /// @notice Identifier of the vault's greenlisted role in Midas access control
    function greenlistedRole() external view returns (bytes32);

    /// @notice Address of the Midas redemption vault
    function midasRedemptionVault() external view returns (address);

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

    /// @notice Grants the greenlisted role to the calling eligible credit account
    function receiveGreenlist() external;

    /// @notice Returns the pending and claimable amounts of quote token for an account, across all counted redeemers
    /// @dev Pending amounts are valued using each redeemer's configured rate source: the live mToken data feed when
    ///      the gateway was deployed with current-rate pricing, otherwise the initial `mTokenRate` stored on the
    ///      redemption request.
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

    /// @notice Returns all redeemers for an account
    /// @param account The account to check
    /// @return redeemers The redeemers for the account
    function redeemers(address account) external view returns (address[] memory redeemers);

    /// @notice Returns whether a credit account owner can redeem mTokens, and the mToken address
    function isEligibleAccountOwner(address account) external view returns (bool, address);
}
