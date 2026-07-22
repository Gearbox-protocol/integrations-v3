// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title Sky Staking Rewards Interface
/// @notice Interface for the Sky StakingRewards contract
interface IStakingRewards {
    function rewardsToken() external view returns (address);
    function stakingToken() external view returns (address);

    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
    function earned(address account) external view returns (uint256);
}

interface IStakingRewardsReferral {
    function stake(uint256 amount, uint16 referral) external;
}
