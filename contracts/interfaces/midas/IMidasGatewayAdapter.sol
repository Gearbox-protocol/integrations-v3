// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {IPhantomTokenAdapter} from "../IPhantomTokenAdapter.sol";

/// @title Midas Gateway adapter interface
/// @notice Combines the issuance and redemption scope of the standalone Midas adapters behind a single gateway
interface IMidasGatewayAdapter is IAdapter, IPhantomTokenAdapter {
    /// @dev Thrown when trying to deposit or redeem with a non-whitelisted token
    error TokenNotAllowedException();

    /// @dev Thrown when the length of the arrays in `setInputTokenAllowedStatusBatch` does not match
    error IncorrectArrayLengthException();

    /// @dev Thrown when trying to set a phantom token that does not match the output token
    error PhantomTokenTokenOutMismatchException();

    /// @notice Midas allowed output token status structure
    struct MidasAllowedTokenStatus {
        address token; // Output token address
        address phantomToken; // Phantom token address (address(0) if only instant redemptions)
        bool allowed; // Whether the token is allowed
    }

    /// @notice Emitted when the allowed status of an input token is updated
    event SetInputTokenAllowedStatus(address indexed token, bool allowed);

    /// @notice Emitted when the allowed status of an output token is updated
    event SetOutputTokenAllowedStatus(address indexed token, address indexed phantomToken, bool allowed);

    // -------- //
    // GENERAL  //
    // -------- //

    /// @notice Address of mToken
    function mToken() external view returns (address);

    /// @notice Address of the gateway
    function gateway() external view returns (address);

    /// @notice Referrer ID used for issuances
    function referrerId() external view returns (bytes32);

    // -------- //
    // ISSUANCE //
    // -------- //

    /// @notice Deposits specified amount of input token for mToken
    /// @param tokenIn Input token address
    /// @param amountToken Amount of input token to deposit
    /// @param minReceiveAmount Minimum amount of mToken to receive
    function depositInstant(address tokenIn, uint256 amountToken, uint256 minReceiveAmount, bytes32)
        external
        returns (bool);

    /// @notice Deposits entire balance of input token, except the specified amount
    /// @param tokenIn Input token address
    /// @param leftoverAmount Amount of input token to keep in the account
    /// @param rateMinRAY Minimum exchange rate from input token to mToken (in RAY format)
    function depositInstantDiff(address tokenIn, uint256 leftoverAmount, uint256 rateMinRAY) external returns (bool);

    /// @notice Returns whether a token is allowed as input for issuances
    /// @param token Token address to check
    function isInputTokenAllowed(address token) external view returns (bool);

    /// @notice Returns all allowed input tokens
    function allowedInputTokens() external view returns (address[] memory);

    /// @notice Sets the allowed status for a batch of input tokens
    /// @param tokens Array of token addresses
    /// @param allowed Array of allowed statuses corresponding to each token
    /// @dev Can only be called by the configurator
    function setInputTokenAllowedStatusBatch(address[] calldata tokens, bool[] calldata allowed) external;

    // ---------- //
    // REDEMPTION //
    // ---------- //

    /// @notice Instantly redeems mToken for output token
    /// @param tokenOut Output token address
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param minReceiveAmount Minimum amount of output token to receive
    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount) external returns (bool);

    /// @notice Instantly redeems mToken for output token, with a leftover amount
    /// @param tokenOut Output token address
    /// @param leftoverAmount Amount of mToken to keep in the account
    /// @param rateMinRAY Minimum exchange rate from mToken to output token (in RAY format)
    function redeemInstantDiff(address tokenOut, uint256 leftoverAmount, uint256 rateMinRAY) external returns (bool);

    /// @notice Requests a redemption of mToken for output token
    /// @param tokenOut Output token address
    /// @param amountMTokenIn Amount of mToken to redeem
    function redeemRequest(address tokenOut, uint256 amountMTokenIn) external returns (bool);

    /// @notice Requests a redemption of mToken for output token with extra logging data
    /// @param tokenOut Output token address
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param extraData Additional redemption data to log
    function redeemRequest(address tokenOut, uint256 amountMTokenIn, bytes calldata extraData) external returns (bool);

    /// @notice Requests a redemption of the entire mToken balance, except the specified amount
    /// @param tokenOut Output token address
    /// @param leftoverAmount Amount of mToken to keep in the account
    function redeemRequestDiff(address tokenOut, uint256 leftoverAmount) external returns (bool);

    /// @notice Requests a redemption of the entire mToken balance, except the specified amount
    /// @param tokenOut Output token address
    /// @param leftoverAmount Amount of mToken to keep in the account
    /// @param extraData Additional redemption data to log
    function redeemRequestDiff(address tokenOut, uint256 leftoverAmount, bytes calldata extraData)
        external
        returns (bool);

    /// @notice Withdraws redeemed tokens from the gateway
    /// @param tokenOut Output token to withdraw
    /// @param amount Amount to withdraw
    function withdraw(address tokenOut, uint256 amount) external returns (bool);

    /// @notice Withdraws tokens from a specific redeemer
    /// @param redeemer The redeemer to withdraw from
    /// @param tokenOut The token to withdraw
    /// @param amount The amount to withdraw
    function withdrawFromRedeemer(address redeemer, address tokenOut, uint256 amount) external returns (bool);

    /// @notice Returns whether a token is allowed as output for redemptions
    /// @param token Token address to check
    function isOutputTokenAllowed(address token) external view returns (bool);

    /// @notice Returns all allowed output tokens
    function allowedOutputTokens() external view returns (address[] memory);

    /// @notice Returns the list of phantom tokens associated to each allowed output token
    function allowedPhantomTokens() external view returns (address[] memory);

    /// @notice Returns the output token that a phantom token tracks
    /// @param phantomToken Phantom token address
    function phantomTokenToOutputToken(address phantomToken) external view returns (address);

    /// @notice Returns the phantom token associated to an output token
    /// @param outputToken Output token address
    function outputTokenToPhantomToken(address outputToken) external view returns (address);

    /// @notice Sets the allowed status for a batch of output tokens
    /// @param configs Array of MidasAllowedTokenStatus structs
    /// @dev Can only be called by the configurator
    function setOutputTokenAllowedStatusBatch(MidasAllowedTokenStatus[] calldata configs) external;

    // ----------------- //
    // TRANSFER REDEEMER //
    // ----------------- //

    /// @notice Transfers a redeemer to a new account
    /// @param redeemer The redeemer to transfer
    /// @param newAccount The new account to transfer the redeemer to
    function transferRedeemer(address redeemer, address newAccount) external returns (bool);
}
