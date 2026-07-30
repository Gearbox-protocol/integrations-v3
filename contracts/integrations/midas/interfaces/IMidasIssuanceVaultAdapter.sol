// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

/// @title Midas Issuance Vault adapter interface
interface IMidasIssuanceVaultAdapter is IAdapter {
    /// @notice Emitted when an input token's allowed status is updated
    event SetInputTokenStatus(address indexed token, bool allowed);

    /// @notice Thrown when token and status arrays have different lengths
    error IncorrectArrayLengthException();

    /// @notice Address of mToken
    function mToken() external view returns (address);

    /// @notice Address of the issuance vault
    function issuanceVault() external view returns (address);

    /// @notice Referrer ID used for issuances
    function referrerId() external view returns (bytes32);

    /// @notice Deposits specified amount of an allowed input token for mToken
    /// @param tokenIn Input token to deposit
    /// @param amountToken Amount of input token to deposit
    /// @param minReceiveAmount Minimum amount of mToken to receive
    function depositInstant(address tokenIn, uint256 amountToken, uint256 minReceiveAmount, bytes32)
        external
        returns (bool);

    /// @notice Deposits entire balance of an allowed input token, except the specified amount
    /// @param tokenIn Input token to deposit
    /// @param leftoverAmount Amount of input token to keep in the account
    /// @param rateMinRAY Minimum exchange rate from input token to mToken (in RAY format)
    function depositInstantDiff(address tokenIn, uint256 leftoverAmount, uint256 rateMinRAY) external returns (bool);

    /// @notice Returns whether `token` is allowed as an input token
    function isInputTokenAllowed(address token) external view returns (bool);

    /// @notice Returns the list of allowed input tokens
    function supportedInputTokens() external view returns (address[] memory);

    /// @notice Sets allowed status for a batch of input tokens
    /// @param tokens Tokens to update
    /// @param statuses Parallel array of allowed flags
    function setInputTokenStatusBatch(address[] calldata tokens, bool[] calldata statuses) external;
}
