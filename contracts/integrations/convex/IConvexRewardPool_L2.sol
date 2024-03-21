// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IConvexRewardPool_L2 {
    struct EarnedData {
        address token;
        uint256 amount;
    }

    struct RewardType {
        address reward_token;
        uint128 reward_integral;
        uint128 reward_remaining;
    }

    function setExtraReward(address) external;
    function setRewardHook(address) external;
    function rewardHook() external view returns (address _hook);
    function getReward(address) external;
    function user_checkpoint(address) external;
    function rewardLength() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function rewards(uint256 _rewardIndex) external view returns (RewardType memory);
    function earnedView(address _account) external view returns (EarnedData[] memory claimable);
    function earned(address _account) external returns (EarnedData[] memory claimable);
    function stakeFor(address _for, uint256 _amount) external returns (bool);
    function withdraw(uint256 amount, bool claim) external returns (bool);
    function withdrawAll(bool claim) external;
    function emergencyWithdraw(uint256 _amount) external returns (bool);
    function convexBooster() external view returns (address);
    function convexPoolId() external view returns (uint256);
}
