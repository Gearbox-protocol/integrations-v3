// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {ICAChecker} from "../../common/interfaces/ICAChecker.sol";
import {IRedemptionLogging} from "../../common/interfaces/IRedemptionLogging.sol";
import {MidasMode} from "./IMidasRedemptionGateway.sol";

/// @dev Bounds the loops that iterate an account's pending depositors, `withdraw` above all
uint256 constant MAX_PENDING_DEPOSITORS_PER_ACCOUNT = 10;

/// @title Midas Deposit Gateway interface
/// @notice External interface of the Midas delayed-deposit gateway
interface IMidasDepositGateway is IVersion, ICAChecker, IRedemptionLogging {
    /// @dev Thrown when attempting to transfer a depositor to a new account without permission
    error DepositorTransferNotAllowedException();
    /// @dev Thrown when attempting to transfer a depositor to a new account that is not greenlisted
    error NewAccountNotGreenlistedException();
    /// @dev Thrown when a non-owner attempts to manage a depositor
    error DepositorNotOwnedByAccountException();
    /// @dev Thrown when a non-permissionless mode is configured but the Midas vault has no access control
    error AccessControlNotSetException();
    /// @dev Thrown when attempting to create a new depositor for an account that has too many pending depositors
    error MaxPendingDepositorsPerAccountException();
    /// @dev Thrown when attempting to withdraw more tokens than all account's depositors have
    error InsufficientBalanceException();
    /// @dev Thrown when attempting to request a greenlist in a non-permissioned mode
    error GreenlistRequestedInNonPermissionedModeException();

    /// @notice Address of the mToken
    function mToken() external view returns (address);

    /// @notice Address of the payment token used for deposits
    function tokenIn() external view returns (address);

    /// @notice Address of the deposit phantom token
    function phantomToken() external view returns (address);

    /// @notice Address of the transfer master that can enable depositor transfers (e.g. during liquidations)
    function transferMaster() external view returns (address);

    /// @notice Address of the Midas access control contract
    function accessControl() external view returns (address);

    /// @notice Access mode of the gateway
    function mode() external view returns (MidasMode);

    /// @notice Identifier of the vault's greenlisted role in Midas access control
    function greenlistedRole() external view returns (bytes32);

    /// @notice Address of the Midas deposit vault
    function midasDepositVault() external view returns (address);

    /// @notice Referrer ID used for all deposits through this gateway
    function referrerId() external view returns (bytes32);

    /// @notice Requests a deposit of `tokenIn` for mToken
    /// @param amountTokenIn Amount of payment token to deposit (native decimals)
    /// @param extraData Additional deposit data to log
    function requestDeposit(uint256 amountTokenIn, bytes calldata extraData) external;

    /// @notice Requests a deposit with a non-zero instant share
    /// @param amountTokenIn Amount of payment token to deposit (native decimals)
    /// @param instantShare Fraction (in bp) of the amount to deposit instantly
    /// @param minReceiveAmountInstantShare Minimum amount of mToken to receive for the instant share
    /// @param extraData Additional deposit data to log
    function requestDepositHybrid(
        uint256 amountTokenIn,
        uint256 instantShare,
        uint256 minReceiveAmountInstantShare,
        bytes calldata extraData
    ) external;

    /// @notice Withdraws minted mToken from funded depositors
    /// @param amount Amount of mToken to withdraw
    function withdraw(uint256 amount) external;

    /// @notice Withdraws mToken from a specific depositor
    /// @param depositor The depositor to withdraw from
    /// @param amount The amount to withdraw
    function withdrawFromDepositor(address depositor, uint256 amount) external;

    /// @notice Transfers a depositor to a new account
    /// @param depositor The depositor to transfer
    /// @param newAccount The new account to transfer the depositor to
    function transferDepositor(address depositor, address newAccount) external;

    /// @notice Grants the greenlisted role to the calling eligible credit account
    function receiveGreenlist() external;

    /// @notice Returns the pending and claimable amounts of mToken for an account
    /// @param account Account to check
    /// @return pendingAmount Pending amount of mToken
    /// @return claimableAmount Claimable amount of mToken
    function pendingAndClaimableTokenOutAmounts(address account)
        external
        view
        returns (uint256 pendingAmount, uint256 claimableAmount);

    /// @notice Returns the pending depositors for an account
    function pendingDepositors(address account) external view returns (address[] memory);

    /// @notice Returns all depositors for an account
    function depositors(address account) external view returns (address[] memory);

    /// @notice Returns whether a credit account owner can deposit, and the mToken address
    function isEligibleAccountOwner(address account) external view returns (bool, address);
}
