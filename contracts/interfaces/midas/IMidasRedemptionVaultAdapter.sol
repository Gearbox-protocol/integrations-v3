// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {IPhantomTokenAdapter} from "../IPhantomTokenAdapter.sol";

interface IMidasRedemptionVaultAdapter is IAdapter, IPhantomTokenAdapter {
    /// @dev Thrown when trying to redeem with a non-whitelisted token
    error TokenNotAllowedException();

    /// @dev Thrown when trying to set a phantom token that does not match the output token
    error PhantomTokenTokenOutMismatchException();

    /// @notice Midas allowed token status structure
    struct MidasAllowedTokenStatus {
        address token; // Output token address
        address phantomToken; // Phantom token address (address(0) if only instant redemptions)
        bool allowed; // Whether the token is allowed
    }

    /// @notice Emitted when the allowed status of an output token is updated
    event SetTokenAllowedStatus(address indexed token, address indexed phantomToken, bool allowed);

    /// @notice Address of mToken
    function mToken() external view returns (address);

    /// @notice Address of the gateway
    function gateway() external view returns (address);

    /// @notice Instantly redeems mToken for output token
    /// @param tokenOut Output token address
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param minReceiveAmount Minimum amount of output token to receive
    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount)
        external
        returns (bool);

    /// @notice Instantly redeems mToken for output token, with a leftover amount
    /// @param tokenOut Output token address
    /// @param leftoverAmount Amount of mToken to keep in the account
    /// @param rateMinRAY Minimum exchange rate from input token to mToken (in RAY format)
    function redeemInstantDiff(address tokenOut, uint256 leftoverAmount, uint256 rateMinRAY) external returns (bool);

    /// @notice Requests a redemption of mToken for output token
    /// @param tokenOut Output token address
    /// @param amountMTokenIn Amount of mToken to redeem
    function redeemRequest(address tokenOut, uint256 amountMTokenIn) external returns (bool);

    /// @notice Withdraws redeemed tokens from the gateway
    /// @param amount Amount to withdraw
    function withdraw(uint256 amount) external returns (bool);

    /// @notice Returns whether a token is allowed as output for redemptions
    /// @param token Token address to check
    function isTokenAllowed(address token) external view returns (bool);

    /// @notice Returns all allowed output tokens
    function allowedTokens() external view returns (address[] memory);

    /// @notice Returns the output token that a phantom token tracks
    /// @param phantomToken Phantom token address
    /// @return Output token address
    function phantomTokenToOutputToken(address phantomToken) external view returns (address);

    /// @notice Sets the allowed status for a batch of output tokens
    /// @param configs Array of MidasAllowedTokenStatus structs
    /// @dev Can only be called by the configurator
    function setTokenAllowedStatusBatch(MidasAllowedTokenStatus[] calldata configs) external;
}
