// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import "../../../integrations/convex/Interfaces.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {Test} from "forge-std/Test.sol";

contract VirtualBalanceWrapper is Test {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IDeposit public deposits;

    function totalSupply() public view returns (uint256) {
        return deposits.totalSupply();
    }

    function balanceOf(address account) public view returns (uint256) {
        return deposits.balanceOf(account);
    }
}

contract ExtraRewardPoolMock is VirtualBalanceWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for ERC20Mock;

    ERC20Mock public rewardToken;
    uint256 public constant duration = 7 days;

    address public operator;

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public queuedRewards = 0;
    uint256 public currentRewards = 0;
    uint256 public historicalRewards = 0;
    uint256 public constant newRewardRatio = 830;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    /// MOCK PARAMS
    uint256 totalRewards = 0;
    uint256 index = 0;

    constructor(address deposit_, address reward_, address op_) {
        deposits = IDeposit(deposit_);
        rewardToken = ERC20Mock(reward_);
        operator = op_;
    }

    modifier updateReward(address account) {
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        return rewardPerTokenStored;
    }

    function earned(address account) public view returns (uint256) {
        return balanceOf(account).mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(
            rewards[account]
        );
    }

    function stake(address _account, uint256) public updateReward(_account) returns (bool) {
        index += 1;
        return true;
    }

    function withdraw(address _account, uint256) public updateReward(_account) returns (bool) {
        index += 1;
        return true;
    }

    function getReward(address _account) public updateReward(_account) returns (bool) {
        uint256 reward = earned(_account);
        if (reward > 0) {
            rewards[_account] = 0;
            rewardToken.safeTransfer(_account, reward);
        }

        index += 1;
        return true;
    }

    function getReward() external returns (bool) {
        getReward(msg.sender);
        return true;
    }

    function donate(uint256) external pure returns (bool) {
        return true;
    }

    function queueNewRewards(uint256) external pure returns (bool) {
        return true;
    }

    function notifyRewardAmount(uint256 reward) internal updateReward(address(0)) {}

    ///
    /// MOCK FUNCTIONS
    ///

    function addRewardAmount(uint256 amount) public {
        vm.prank(rewardToken.minter());
        rewardToken.mint(address(this), amount);

        if (totalSupply() != 0) {
            rewardPerTokenStored += (amount * 1e18) / totalSupply();
        }
    }
}
