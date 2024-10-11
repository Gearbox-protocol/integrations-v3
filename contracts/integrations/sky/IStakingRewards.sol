// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/// @title Sky Staking Rewards Interface
/// @notice Interface for the Sky StakingRewards contract
interface IStakingRewards {
    function rewardsToken() external view returns (address);
    function stakingToken() external view returns (address);

    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
}
