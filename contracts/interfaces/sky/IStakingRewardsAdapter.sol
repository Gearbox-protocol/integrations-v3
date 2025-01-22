// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";

/// @title Staking Rewards Adapter Interface
/// @notice Interface for the Staking Rewards adapter contract
interface IStakingRewardsAdapter is IAdapter {
    /// @notice Address of the staking token
    function stakingToken() external view returns (address);

    /// @notice Address of the rewards token
    function rewardsToken() external view returns (address);

    /// @notice Address of a phantom token representing account's stake in the reward pool
    function stakedPhantomToken() external view returns (address);

    /// @notice Collateral token mask of staking token in the credit manager
    function stakingTokenMask() external view returns (uint256);

    /// @notice Collateral token mask of rewards token in the credit manager
    function rewardsTokenMask() external view returns (uint256);

    /// @notice Collateral token mask of staked phantom token in the credit manager
    function stakedPhantomTokenMask() external view returns (uint256);

    /// @notice Stakes tokens in the StakingRewards contract
    /// @param amount Amount of tokens to stake
    function stake(uint256 amount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    /// @notice Stakes the entire balance of staking token, except the specified amount
    /// @param leftoverAmount Amount of staking token to keep on the account
    function stakeDiff(uint256 leftoverAmount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    /// @notice Claims rewards on the current position
    function getReward() external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    /// @notice Withdraws staked tokens from the StakingRewards contract
    /// @param amount Amount of tokens to withdraw
    function withdraw(uint256 amount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    /// @notice Withdraws the entire balance of staked tokens, except the specified amount
    /// @param leftoverAmount Amount of staked tokens to keep in the contract
    function withdrawDiff(uint256 leftoverAmount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);
}
