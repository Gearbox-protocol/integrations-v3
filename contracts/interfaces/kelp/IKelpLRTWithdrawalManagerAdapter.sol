// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IPhantomTokenAdapter} from "../IPhantomTokenAdapter.sol";

struct TokenOutStatus {
    address tokenOut;
    address phantomToken;
    bool allowed;
}

/// @title Kelp LRT Withdrawal Manager adapter interface
interface IKelpLRTWithdrawalManagerAdapter is IPhantomTokenAdapter {
    /// @notice Thrown when attempting to initiate a withdrawal for a token that is not allowed.
    error TokenNotAllowedException();

    /// @notice Initiates a withdrawal for a specific amount of assets
    /// @param asset The asset to withdraw
    /// @param amount The amount of assets to withdraw
    /// @param referralId The referral ID
    function initiateWithdrawal(address asset, uint256 amount, string calldata referralId) external returns (bool);

    /// @notice Initiates a withdrawal for a specific amount of assets, except the specified amount
    /// @param asset The asset to withdraw
    /// @param leftoverAmount The amount of assets to leave on the credit account
    function initiateWithdrawalDiff(address asset, uint256 leftoverAmount) external returns (bool);

    /// @notice Claims a specific amount of assets from completed withdrawals
    /// @param asset The asset to withdraw
    /// @param amount The amount of asset to claim
    /// @param referralId The referral ID
    function completeWithdrawal(address asset, uint256 amount, string calldata referralId) external returns (bool);

    /// @notice Returns the list of allowed withdrawable tokens
    function getAllowedTokensOut() external view returns (address[] memory);

    /// @notice Returns the list of phantom tokens associated with allowed withdrawable tokens

    /// @notice Returns the list of phantom tokens associated with allowed withdrawable tokens
    function getPhantomTokensForAllowedTokensOut() external view returns (address[] memory);

    /// @notice Sets the status of a batch of output tokens
    /// @param tokensOut The batch of output tokens to set the status for
    function setTokensOutBatchStatus(TokenOutStatus[] calldata tokensOut) external;
}
