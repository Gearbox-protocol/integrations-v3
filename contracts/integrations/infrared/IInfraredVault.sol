// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct UserReward {
    address token;
    uint256 amount;
}

interface IInfraredVault {
    function totalSupply() external view returns (uint256);
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
    function exit() external;
    function balanceOf(address account) external view returns (uint256);
    function earned(address account, address _rewardsToken) external view returns (uint256);
    function getRewardForUser(address _user) external;
    function getAllRewardTokens() external view returns (address[] memory);
    function getAllRewardsForUser(address _user) external view returns (UserReward[] memory);
    function infrared() external view returns (address);
    function rewardsVault() external view returns (address);
    function stakingToken() external view returns (address);
}
