// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {IStakingRewards} from "../../integrations/sky/IStakingRewards.sol";
import {IStakingRewardsAdapter} from "../../interfaces/sky/IStakingRewardsAdapter.sol";

/// @title Staking Rewards adapter
/// @notice Implements logic for interacting with StakingRewards contract
contract StakingRewardsAdapter is AbstractAdapter, IStakingRewardsAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.STAKING_REWARDS;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @notice Address of the staking token
    address public immutable override stakingToken;

    /// @notice Address of the rewards token
    address public immutable override rewardsToken;

    /// @notice Address of a phantom token representing account's stake in the reward pool
    address public immutable override stakedPhantomToken;

    /// @notice Collateral token mask of staking token in the credit manager
    uint256 public immutable override stakingTokenMask;

    /// @notice Collateral token mask of rewards token in the credit manager
    uint256 public immutable override rewardsTokenMask;

    /// @notice Collateral token mask of staked phantom token in the credit manager
    uint256 public immutable override stakedPhantomTokenMask;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _stakingRewards StakingRewards contract address
    /// @param _stakedPhantomToken Staked phantom token address
    constructor(address _creditManager, address _stakingRewards, address _stakedPhantomToken)
        AbstractAdapter(_creditManager, _stakingRewards)
    {
        stakingToken = IStakingRewards(_stakingRewards).stakingToken();
        rewardsToken = IStakingRewards(_stakingRewards).rewardsToken();
        stakedPhantomToken = _stakedPhantomToken;

        stakingTokenMask = _getMaskOrRevert(stakingToken);
        rewardsTokenMask = _getMaskOrRevert(rewardsToken);
        stakedPhantomTokenMask = _getMaskOrRevert(stakedPhantomToken);
    }

    // ----- //
    // STAKE //
    // ----- //

    /// @notice Stakes tokens in the StakingRewards contract
    /// @param amount Amount of tokens to stake
    function stake(uint256 amount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _stake(amount, false);
    }

    /// @notice Stakes the entire balance of staking token, except the specified amount
    /// @param leftoverAmount Amount of staking token to keep on the account
    function stakeDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();

        uint256 balance = IERC20(stakingToken).balanceOf(creditAccount);

        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) = _stake(balance - leftoverAmount, leftoverAmount <= 1);
            }
        }
    }

    /// @dev Internal implementation of `stake` and `stakeDiff`
    function _stake(uint256 amount, bool disableStakingToken)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approveToken(stakingToken, type(uint256).max);
        _execute(abi.encodeCall(IStakingRewards.stake, (amount)));
        _approveToken(stakingToken, 1);
        (tokensToEnable, tokensToDisable) = (stakedPhantomTokenMask, disableStakingToken ? stakingTokenMask : 0);
    }

    // ----- //
    // CLAIM //
    // ----- //

    /// @notice Claims rewards on the current position
    function getReward() external override creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        _execute(abi.encodeCall(IStakingRewards.getReward, ()));
        (tokensToEnable, tokensToDisable) = (rewardsTokenMask, 0);
    }

    // -------- //
    // WITHDRAW //
    // -------- //

    /// @notice Withdraws staked tokens from the StakingRewards contract
    /// @param amount Amount of tokens to withdraw
    function withdraw(uint256 amount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdraw(amount, false);
    }

    /// @notice Withdraws the entire balance of staked tokens, except the specified amount
    /// @param leftoverAmount Amount of staked tokens to keep in the contract
    function withdrawDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();

        uint256 balance = IERC20(stakedPhantomToken).balanceOf(creditAccount);

        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) = _withdraw(balance - leftoverAmount, leftoverAmount <= 1);
            }
        }
    }

    /// @dev Internal implementation of `withdraw` and `withdrawDiff`
    function _withdraw(uint256 amount, bool disableStakedToken)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(abi.encodeCall(IStakingRewards.withdraw, (amount)));
        (tokensToEnable, tokensToDisable) = (stakingTokenMask, disableStakedToken ? stakedPhantomTokenMask : 0);
    }
}
