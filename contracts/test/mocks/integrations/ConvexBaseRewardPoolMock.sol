// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import "../../../integrations/convex/Interfaces.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20Mock } from "@gearbox-protocol/core-v2/contracts/test/mocks/token/ERC20Mock.sol";
import { CheatCodes, HEVM_ADDRESS } from "@gearbox-protocol/core-v2/contracts/test/lib/cheatCodes.sol";
import { MathUtil } from "@gearbox-protocol/core-v2/contracts/test/lib/MathUtil.sol";

contract BaseRewardPoolMock {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for ERC20Mock;

    ERC20Mock public rewardToken;
    IERC20 public stakingToken;
    uint256 public constant duration = 7 days;

    address public operator;
    address public rewardManager;

    uint256 public pid;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public queuedRewards = 0;
    uint256 public currentRewards = 0;
    uint256 public historicalRewards = 0;
    uint256 public constant newRewardRatio = 830;
    uint256 private _totalSupply;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) private _balances;

    address[] public extraRewards;

    /// MOCK PARAMS
    uint256 totalRewards = 0;
    uint256 index = 0;

    constructor(
        uint256 pid_,
        address stakingToken_,
        address rewardToken_,
        address operator_
    ) {
        pid = pid_;
        stakingToken = IERC20(stakingToken_);
        rewardToken = ERC20Mock(rewardToken_);
        operator = operator_;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function extraRewardsLength() external view returns (uint256) {
        return extraRewards.length;
    }

    function addExtraReward(address _reward) external returns (bool) {
        require(_reward != address(0), "!reward setting");

        extraRewards.push(_reward);
        return true;
    }

    function clearExtraRewards() external {
        delete extraRewards;
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
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return MathUtil.min(block.timestamp, periodFinish);
    }

    function stake(uint256 _amount)
        public
        updateReward(msg.sender)
        returns (bool)
    {
        require(_amount > 0, "RewardPool : Cannot stake 0");

        //also stake to linked rewards
        for (uint256 i = 0; i < extraRewards.length; i++) {
            IRewards(extraRewards[i]).stake(msg.sender, _amount);
        }

        _totalSupply = _totalSupply.add(_amount);
        _balances[msg.sender] = _balances[msg.sender].add(_amount);

        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        index += 1;

        return true;
    }

    function stakeAll() external returns (bool) {
        uint256 balance = stakingToken.balanceOf(msg.sender);
        stake(balance);
        return true;
    }

    function stakeFor(address _for, uint256 _amount)
        public
        updateReward(_for)
        returns (bool)
    {
        require(_amount > 0, "RewardPool : Cannot stake 0");

        //also stake to linked rewards
        for (uint256 i = 0; i < extraRewards.length; i++) {
            IRewards(extraRewards[i]).stake(_for, _amount);
        }

        //give to _for
        _totalSupply = _totalSupply.add(_amount);
        _balances[_for] = _balances[_for].add(_amount);

        //take away from sender
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        index += 1;

        return true;
    }

    function withdraw(uint256 amount, bool claim)
        public
        updateReward(msg.sender)
        returns (bool)
    {
        require(amount > 0, "RewardPool : Cannot withdraw 0");

        //also withdraw from linked rewards
        for (uint256 i = 0; i < extraRewards.length; i++) {
            IRewards(extraRewards[i]).withdraw(msg.sender, amount);
        }

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);

        stakingToken.safeTransfer(msg.sender, amount);

        if (claim) {
            getReward(msg.sender, true);
        }

        index += 1;
        return true;
    }

    function withdrawAll(bool claim) external {
        withdraw(_balances[msg.sender], claim);
    }

    function withdrawAndUnwrap(uint256 amount, bool claim)
        public
        updateReward(msg.sender)
        returns (bool)
    {
        //also withdraw from linked rewards
        for (uint256 i = 0; i < extraRewards.length; i++) {
            IRewards(extraRewards[i]).withdraw(msg.sender, amount);
        }

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);

        //tell operator to withdraw from here directly to user
        IDeposit(operator).withdrawTo(pid, amount, msg.sender);

        //get rewards too
        if (claim) {
            getReward(msg.sender, true);
        }

        index += 1;
        return true;
    }

    function withdrawAllAndUnwrap(bool claim) external {
        withdrawAndUnwrap(_balances[msg.sender], claim);
    }

    function getReward(address _account, bool _claimExtras)
        public
        updateReward(_account)
        returns (bool)
    {
        uint256 reward = earned(_account);
        if (reward > 0) {
            rewards[_account] = 0;
            rewardToken.safeTransfer(_account, reward);
            IDeposit(operator).rewardClaimed(pid, _account, reward);
        }

        //also get rewards from linked rewards
        if (_claimExtras) {
            for (uint256 i = 0; i < extraRewards.length; i++) {
                IRewards(extraRewards[i]).getReward(_account);
            }
        }

        index += 1;
        return true;
    }

    function getReward() external returns (bool) {
        getReward(msg.sender, true);
        return true;
    }

    function donate(uint256) external pure returns (bool) {
        return true;
    }

    function queueNewRewards(uint256) external pure returns (bool) {
        return true;
    }

    function notifyRewardAmount(uint256 reward)
        internal
        updateReward(address(0))
    {}

    ///
    /// MOCK FUNCTIONS
    ///

    function addRewardAmount(uint256 amount) public {
        evm.prank(rewardToken.minter());
        rewardToken.mint(address(this), amount);

        if (totalSupply() != 0) {
            rewardPerTokenStored += (amount * 1e18) / totalSupply();
        }
    }
}
