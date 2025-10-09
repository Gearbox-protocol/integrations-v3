// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

interface IMidasRedemptionVaultGateway is IVersion {
    /// @notice Structure to store pending redemption requests
    struct PendingRedemption {
        bool isActive;
        uint256 requestId;
        uint256 timestamp;
        uint256 remainder;
    }

    /// @notice Address of the Midas Redemption Vault
    function midasRedemptionVault() external view returns (address);

    /// @notice Address of the mToken
    function mToken() external view returns (address);

    /// @notice Returns pending redemption data for a user
    function pendingRedemptions(address user)
        external
        view
        returns (bool isActive, uint256 requestId, uint256 timestamp, uint256 remainder);

    /// @notice Instantly redeems mToken for output token
    /// @param tokenOut Token to receive from redemption
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param minReceiveAmount Minimum amount of output token to receive
    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount) external;

    /// @notice Requests a redemption from the vault
    /// @param tokenOut Token to receive from redemption
    /// @param amountMTokenIn Amount of mToken to redeem
    function requestRedeem(address tokenOut, uint256 amountMTokenIn) external;

    /// @notice Withdraws redeemed tokens once the redemption is fulfilled
    /// @param amount Amount of tokenOut to withdraw
    function withdraw(uint256 amount) external;

    /// @notice Returns the expected amount of tokenOut for a user's pending redemption
    /// @param user User address
    /// @param tokenOut Token to check (returns 0 if different from pending redemption token)
    function pendingTokenOutAmount(address user, address tokenOut) external view returns (uint256);
}
