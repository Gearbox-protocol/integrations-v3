// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {IRedemptionLogging} from "../../common/interfaces/IRedemptionLogging.sol";

/// @dev Bounds the loops that iterate an account's pending redeemers
uint256 constant MAX_PENDING_REDEEMERS_PER_ACCOUNT = 10;

/// @title Treehouse redemption gateway interface
/// @notice External interface of the Treehouse delayed-redemption gateway
interface ITreehouseRedemptionGateway is IVersion, IRedemptionLogging {
    /// @dev Thrown when attempting to transfer a redeemer to a new account without permission
    error RedeemerTransferNotAllowedException();

    /// @dev Thrown when a non-owner attempts to manage a redeemer
    error RedeemerNotOwnedByAccountException();

    /// @dev Thrown when attempting to create a new redeemer for an account that has too many pending redeemers
    error MaxPendingRedeemersPerAccountException();

    /// @notice Address of the Treehouse RedemptionV3 contract
    function redemptionV3() external view returns (address);

    /// @notice Address of the TAsset contract
    function tAsset() external view returns (address);

    /// @notice Address of the underlying token of the vault
    function vaultUnderlying() external view returns (address);

    /// @notice Address of the transfer master that can enable redeemer transfers (e.g. during liquidations)
    function transferMaster() external view returns (address);

    /// @notice Address of the master redeemer contract used for cloning
    function masterRedeemer() external view returns (address);

    /// @notice Address of the redemption phantom token
    function phantomToken() external view returns (address);

    /// @notice Redeems TAsset shares via a new redeemer clone
    /// @param shares Amount of TAsset shares to redeem
    /// @param extraData Additional redemption data to log
    function redeem(uint256 shares, bytes calldata extraData) external;

    /// @notice Finalizes a redemption request and sends underlying to the account
    /// @param redeemer The redeemer to finalize
    function finalizeRedeem(address redeemer) external;

    /// @notice Transfers a redeemer to a new account
    /// @param redeemer The redeemer to transfer
    /// @param newAccount The new account to transfer the redeemer to
    function transferRedeemer(address redeemer, address newAccount) external;

    /// @notice Returns the pending and claimable amounts of vault underlying for an account
    /// @param account Account to check
    /// @return pendingAmount Pending amount of vault underlying
    /// @return claimableAmount Claimable amount of vault underlying
    function pendingAndClaimableAmounts(address account)
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
}
