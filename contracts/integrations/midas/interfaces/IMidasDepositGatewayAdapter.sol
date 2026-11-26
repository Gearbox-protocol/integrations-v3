// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {IPhantomTokenAdapter} from "../../common/interfaces/IPhantomTokenAdapter.sol";

/// @title Midas Deposit Gateway adapter interface
/// @notice Delayed-deposit adapter for the Midas deposit gateway
interface IMidasDepositGatewayAdapter is IAdapter, IPhantomTokenAdapter {
    error PhantomTokenNotSetException();

    /// @notice Address of mToken
    function mToken() external view returns (address);

    /// @notice Address of the gateway
    function gateway() external view returns (address);

    /// @notice Address of the payment token used for deposits
    function tokenIn() external view returns (address);

    /// @notice Address of the deposit phantom token
    function phantomToken() external view returns (address);

    /// @notice Grants the greenlisted role to the credit account via the gateway
    function receiveGreenlist() external returns (bool);

    /// @notice Requests a deposit of payment token for mToken
    /// @param amountTokenIn Amount of payment token to deposit
    function depositRequest(uint256 amountTokenIn) external returns (bool);

    /// @notice Requests a deposit of payment token for mToken with extra logging data
    /// @param amountTokenIn Amount of payment token to deposit
    /// @param extraData Additional deposit data to log
    function depositRequest(uint256 amountTokenIn, bytes calldata extraData) external returns (bool);

    /// @notice Requests a deposit of the entire payment-token balance, except the specified amount
    /// @param leftoverAmount Amount of payment token to keep in the account
    function depositRequestDiff(uint256 leftoverAmount) external returns (bool);

    /// @notice Requests a deposit of the entire payment-token balance, except the specified amount
    /// @param leftoverAmount Amount of payment token to keep in the account
    /// @param extraData Additional deposit data to log
    function depositRequestDiff(uint256 leftoverAmount, bytes calldata extraData) external returns (bool);

    /// @notice Requests a deposit with part of the deposit immediately fulfilled
    /// @param amountTokenIn Amount of payment token to deposit
    /// @param instantShare Fraction (in bp) of the amount to deposit instantly
    /// @param minReceiveAmountInstantShare Minimum amount of mToken to receive for the instant share
    function depositRequestHybrid(uint256 amountTokenIn, uint256 instantShare, uint256 minReceiveAmountInstantShare)
        external
        returns (bool);

    /// @notice Requests a deposit with part of the deposit immediately fulfilled
    /// @param amountTokenIn Amount of payment token to deposit
    /// @param instantShare Fraction (in bp) of the amount to deposit instantly
    /// @param minReceiveAmountInstantShare Minimum amount of mToken to receive for the instant share
    /// @param extraData Additional deposit data to log
    function depositRequestHybrid(
        uint256 amountTokenIn,
        uint256 instantShare,
        uint256 minReceiveAmountInstantShare,
        bytes calldata extraData
    ) external returns (bool);

    /// @notice Requests a deposit of the entire payment-token balance except leftover, with a hybrid instant share
    /// @param leftoverAmount Amount of payment token to keep in the account
    /// @param instantShare Fraction (in bp) of the amount to deposit instantly
    /// @param minInstantRateRAY Minimum exchange rate from payment token to mToken for the instant share (RAY)
    function depositRequestHybridDiff(uint256 leftoverAmount, uint256 instantShare, uint256 minInstantRateRAY)
        external
        returns (bool);

    /// @notice Requests a deposit of the entire payment-token balance except leftover, with a hybrid instant share
    /// @param leftoverAmount Amount of payment token to keep in the account
    /// @param instantShare Fraction (in bp) of the amount to deposit instantly
    /// @param minInstantRateRAY Minimum exchange rate from payment token to mToken for the instant share (RAY)
    /// @param extraData Additional deposit data to log
    function depositRequestHybridDiff(
        uint256 leftoverAmount,
        uint256 instantShare,
        uint256 minInstantRateRAY,
        bytes calldata extraData
    ) external returns (bool);

    /// @notice Withdraws minted mToken from the gateway
    /// @param amount Amount to withdraw
    function withdraw(uint256 amount) external returns (bool);

    /// @notice Withdraws mToken from a specific depositor
    /// @param depositor The depositor to withdraw from
    /// @param amount The amount to withdraw
    function withdrawFromDepositor(address depositor, uint256 amount) external returns (bool);

    /// @notice Transfers a depositor to a new account
    /// @param depositor The depositor to transfer
    /// @param newAccount The new account to transfer the depositor to
    function transferDepositor(address depositor, address newAccount) external returns (bool);
}
