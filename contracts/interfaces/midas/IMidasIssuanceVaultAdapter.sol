// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

interface IMidasIssuanceVaultAdapter is IAdapter {
    /// @dev Thrown when trying to deposit with a non-whitelisted token
    error TokenNotAllowedException();

    /// @dev Thrown when the length of the arrays in setTokenAllowedStatusBatch does not match
    error IncorrectArrayLengthException();

    /// @notice Emitted when the allowed status of an input token is updated
    event SetTokenAllowedStatus(address indexed token, bool allowed);

    /// @notice Address of mToken
    function mToken() external view returns (address);

    /// @notice Referrer ID used for deposits
    function referrerId() external view returns (bytes32);

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

    /// @notice Returns whether a token is allowed as input for depositInstant
    /// @param token Token address to check
    function isTokenAllowed(address token) external view returns (bool);

    /// @notice Returns all allowed input tokens
    function allowedTokens() external view returns (address[] memory);

    /// @notice Sets the allowed status for a batch of input tokens
    /// @param tokens Array of token addresses
    /// @param allowed Array of allowed statuses corresponding to each token
    /// @dev Can only be called by the configurator
    function setTokenAllowedStatusBatch(address[] calldata tokens, bool[] calldata allowed) external;
}
