// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {AbstractAdapter} from "../AbstractAdapter.sol";
import {BitMask} from "@gearbox-protocol/core-v3/contracts/libraries/BitMask.sol";

import {IStakingRewards} from "../../integrations/sky/IStakingRewards.sol";
import {IStakingRewardsReferral} from "../../integrations/sky/IStakingRewards.sol";
import {IStakingRewardsAdapter} from "../../interfaces/sky/IStakingRewardsAdapter.sol";

/// @title Staking Rewards adapter
/// @notice Implements logic for interacting with a generic StakingRewards contract
contract StakingRewardsAdapter is AbstractAdapter, IStakingRewardsAdapter {
    using BitMask for uint256;

    bytes32 public constant override contractType = "ADAPTER::STAKING_REWARDS";
    uint256 public constant override version = 3_11;

    /// @notice Address of the staking token
    address public immutable override stakingToken;

    /// @notice Address of the rewards token
    address public immutable override rewardsToken;

    /// @notice Address of a phantom token representing account's stake in the reward pool
    address public immutable override stakedPhantomToken;

    /// @notice Referral code for the protocol
    uint16 public immutable override referral;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _stakingRewards StakingRewards contract address
    /// @param _stakedPhantomToken Staked phantom token address
    /// @param _referral Referral code
    constructor(address _creditManager, address _stakingRewards, address _stakedPhantomToken, uint16 _referral)
        AbstractAdapter(_creditManager, _stakingRewards)
    {
        stakingToken = IStakingRewards(_stakingRewards).stakingToken();
        _getMaskOrRevert(stakingToken);

        rewardsToken = IStakingRewards(_stakingRewards).rewardsToken();
        _getMaskOrRevert(rewardsToken);

        stakedPhantomToken = _stakedPhantomToken;
        _getMaskOrRevert(stakedPhantomToken);

        referral = _referral;
    }

    // ----- //
    // STAKE //
    // ----- //

    /// @notice Stakes tokens in the StakingRewards contract
    /// @param amount Amount of tokens to stake
    function stake(uint256 amount) external override creditFacadeOnly returns (bool) {
        _stake(amount);
        return false;
    }

    /// @notice Stakes the entire balance of staking token, except the specified amount
    /// @param leftoverAmount Amount of staking token to keep on the account
    function stakeDiff(uint256 leftoverAmount) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();

        uint256 balance = IERC20(stakingToken).balanceOf(creditAccount);

        if (balance > leftoverAmount) {
            unchecked {
                _stake(balance - leftoverAmount);
            }
        }
        return false;
    }

    /// @dev Stakes tokens in the StakingRewards contract. Uses a special signature if the referral code is not 0.
    function _stake(uint256 amount) internal {
        if (referral == 0) {
            _executeSwapSafeApprove(stakingToken, abi.encodeCall(IStakingRewards.stake, (amount)));
        } else {
            _executeSwapSafeApprove(stakingToken, abi.encodeCall(IStakingRewardsReferral.stake, (amount, referral)));
        }
    }

    /// @notice Deposits into a phantom token
    function depositPhantomToken(address token, uint256 amount) external override creditFacadeOnly returns (bool) {
        if (token != stakedPhantomToken) revert IncorrectStakedPhantomTokenException();
        _stake(amount);
        return false;
    }

    // ----- //
    // CLAIM //
    // ----- //

    /// @notice Claims rewards on the current position
    function getReward() external override creditFacadeOnly returns (bool) {
        _execute(abi.encodeCall(IStakingRewards.getReward, ()));
        return false;
    }

    // -------- //
    // WITHDRAW //
    // -------- //

    /// @notice Withdraws staked tokens from the StakingRewards contract
    /// @param amount Amount of tokens to withdraw
    function withdraw(uint256 amount) external override creditFacadeOnly returns (bool) {
        _execute(abi.encodeCall(IStakingRewards.withdraw, (amount)));
        return false;
    }

    /// @notice Withdraws the entire balance of staked tokens, except the specified amount
    /// @param leftoverAmount Amount of staked tokens to keep in the contract
    function withdrawDiff(uint256 leftoverAmount) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();

        uint256 balance = IERC20(stakedPhantomToken).balanceOf(creditAccount);

        if (balance > leftoverAmount) {
            unchecked {
                _execute(abi.encodeCall(IStakingRewards.withdraw, (balance - leftoverAmount)));
            }
        }

        return false;
    }

    /// @notice Withdraws phantom token for its underlying
    function withdrawPhantomToken(address token, uint256 amount) external override creditFacadeOnly returns (bool) {
        if (token != stakedPhantomToken) revert IncorrectStakedPhantomTokenException();
        _execute(abi.encodeCall(IStakingRewards.withdraw, (amount)));
        return false;
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory) {
        return abi.encode(creditManager, targetContract, stakingToken, rewardsToken, stakedPhantomToken, referral);
    }
}
