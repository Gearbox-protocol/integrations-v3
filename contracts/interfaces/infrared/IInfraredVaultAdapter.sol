// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {IPhantomTokenWithdrawer} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

/// @title InfraredVault Adapter Interface
interface IInfraredVaultAdapter is IAdapter, IPhantomTokenWithdrawer {
    /// @notice Address of the staking token
    function stakingToken() external view returns (address);

    /// @notice Address of the staked phantom token
    function stakedPhantomToken() external view returns (address);

    /// @notice Returns the array of all reward tokens supported by the vault
    function rewardTokens() external view returns (address[] memory);

    /// @notice Stakes tokens in the InfraredVault
    /// @param amount Amount of tokens to stake
    function stake(uint256 amount) external returns (bool useSafePrices);

    /// @notice Stakes the entire balance of staking token, except the specified amount
    /// @param leftoverAmount Amount of staking token to keep on the account
    function stakeDiff(uint256 leftoverAmount) external returns (bool useSafePrices);

    /// @notice Claims all rewards on the current position
    function getReward() external returns (bool useSafePrices);

    /// @notice Withdraws staked tokens from the InfraredVault
    /// @param amount Amount of tokens to withdraw
    function withdraw(uint256 amount) external returns (bool useSafePrices);

    /// @notice Withdraws the entire balance of staked tokens, except the specified amount
    /// @param leftoverAmount Amount of staked tokens to keep in the contract
    function withdrawDiff(uint256 leftoverAmount) external returns (bool useSafePrices);

    /// @notice Exits the staking position by withdrawing all staked tokens and claiming rewards
    function exit() external returns (bool useSafePrices);
}
