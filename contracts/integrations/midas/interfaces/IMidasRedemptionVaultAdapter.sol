// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

/// @title Midas Redemption Vault adapter interface
/// @notice Instant-redemption adapter; delayed redemptions go through the Midas gateway
interface IMidasRedemptionVaultAdapter is IAdapter {
    /// @notice Emitted when an output token's allowed status is updated
    event SetOutputTokenStatus(address indexed token, bool allowed);

    /// @notice Thrown when token and status arrays have different lengths
    error IncorrectArrayLengthException();

    /// @notice Address of mToken
    function mToken() external view returns (address);

    /// @notice Instantly redeems mToken for an allowed output token
    /// @param tokenOut Output token to receive
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param minReceiveAmount Minimum amount of output token to receive
    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount) external returns (bool);

    /// @notice Instantly redeems mToken for an allowed output token, with a leftover amount
    /// @param tokenOut Output token to receive
    /// @param leftoverAmount Amount of mToken to keep in the account
    /// @param rateMinRAY Minimum exchange rate from mToken to output token (in RAY format)
    function redeemInstantDiff(address tokenOut, uint256 leftoverAmount, uint256 rateMinRAY) external returns (bool);

    /// @notice Returns whether `token` is allowed as an output token
    function isOutputTokenAllowed(address token) external view returns (bool);

    /// @notice Returns the list of allowed output tokens
    function supportedOutputTokens() external view returns (address[] memory);

    /// @notice Sets allowed status for a batch of output tokens
    /// @param tokens Tokens to update
    /// @param statuses Parallel array of allowed flags
    function setOutputTokenStatusBatch(address[] calldata tokens, bool[] calldata statuses) external;
}
