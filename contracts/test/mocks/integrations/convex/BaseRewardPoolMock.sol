// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

contract BaseRewardPoolMock {
    uint256 public pid;
    address public operator;
    address public stakingToken;
    address public rewardToken;

    uint256 numExtraRewards;
    address[4] public extraRewards;

    constructor(uint256 _pid, address _operator, address _stakingToken, address _rewardToken) {
        pid = _pid;
        operator = _operator;
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
    }

    function setExtraReward(uint256 i, address extraReward) external {
        extraRewards[i] = extraReward;
    }

    function setNumExtraRewards(uint256 num) external {
        numExtraRewards = num;
    }

    function extraRewardsLength() external view returns (uint256) {
        return numExtraRewards;
    }
}
