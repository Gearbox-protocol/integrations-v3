// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {AdapterType} from "@gearbox-protocol/core-v3/contracts/interfaces/adapters/IAdapter.sol";
import {AbstractAdapter} from "@gearbox-protocol/core-v3/contracts/adapters/AbstractAdapter.sol";

import {IBooster} from "../../integrations/convex/IBooster.sol";
import {IBaseRewardPool} from "../../integrations/convex/IBaseRewardPool.sol";
import {IRewards} from "../../integrations/convex/Interfaces.sol";
import {IConvexV1BaseRewardPoolAdapter} from "../../interfaces/convex/IConvexV1BaseRewardPoolAdapter.sol";

/// @title Convex V1 BaseRewardPool adapter interface
/// @notice Implements logic for interacting with Convex reward pool
contract ConvexV1BaseRewardPoolAdapter is AbstractAdapter, IConvexV1BaseRewardPoolAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.CONVEX_V1_BASE_REWARD_POOL;
    uint16 public constant override _gearboxAdapterVersion = 2;

    /// @notice Address of a Curve LP token deposited into the Convex pool
    address public immutable override curveLPtoken;

    /// @notice Address of a Convex LP token staked in the reward pool
    address public immutable override stakingToken;

    /// @notice Address of a phantom token representing account's stake in the reward pool
    address public immutable override stakedPhantomToken;

    /// @notice Collateral token mask of a Curve LP token in the credit manager
    uint256 public immutable override curveLPTokenMask;

    /// @notice Collateral token mask of a Convex LP token in the credit manager
    uint256 public immutable override stakingTokenMask;

    /// @notice Collateral token mask of a reward pool stake token
    uint256 public immutable override stakedTokenMask;

    /// @notice Bitmask of all reward tokens of the pool (CRV, CVX, extra reward tokens, if any) in the credit manager
    uint256 public immutable override rewardTokensMask;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _baseRewardPool BaseRewardPool address
    /// @param _stakedPhantomToken Reward pool stake token address
    constructor(address _creditManager, address _baseRewardPool, address _stakedPhantomToken)
        AbstractAdapter(_creditManager, _baseRewardPool)
    {
        stakingToken = address(IBaseRewardPool(_baseRewardPool).stakingToken()); // F: [ACVX1_P-1]
        stakingTokenMask = creditManager.tokenMasksMap(stakingToken); // F: [ACVX1_P-1]
        if (stakingTokenMask == 0) {
            revert TokenIsNotInAllowedList(stakingToken); // F: [ACVX1_P-2]
        }

        stakedPhantomToken = _stakedPhantomToken; // F: [ACVX1_P-1]
        stakedTokenMask = creditManager.tokenMasksMap(stakedPhantomToken); // F: [ACVX1_P-1]
        if (stakedTokenMask == 0) {
            revert TokenIsNotInAllowedList(stakedPhantomToken); // F: [ACVX1_P-2]
        }

        address booster = IBaseRewardPool(_baseRewardPool).operator();
        IBooster.PoolInfo memory poolInfo = IBooster(booster).poolInfo(IBaseRewardPool(_baseRewardPool).pid());
        curveLPtoken = poolInfo.lptoken; // F: [ACVX1_P-1]
        curveLPTokenMask = creditManager.tokenMasksMap(curveLPtoken); // F: [ACVX1_P-1]
        if (curveLPTokenMask == 0) {
            revert TokenIsNotInAllowedList(curveLPtoken); // F: [ACVX1_P-2]
        }

        uint256 _rewardTokensMask;
        uint256 mask;

        address rewardToken = address(IBaseRewardPool(_baseRewardPool).rewardToken());
        mask = creditManager.tokenMasksMap(rewardToken);
        if (mask == 0) {
            revert TokenIsNotInAllowedList(rewardToken); // F: [ACVX1_P-2]
        }
        _rewardTokensMask |= mask;

        address cvx = IBooster(booster).minter();
        mask = creditManager.tokenMasksMap(cvx);
        if (mask == 0) {
            revert TokenIsNotInAllowedList(cvx); // F: [ACVX1_P-2]
        }
        _rewardTokensMask |= mask;

        address _extraReward1;
        address _extraReward2;
        uint256 extraRewardLength = IBaseRewardPool(_baseRewardPool).extraRewardsLength();
        if (extraRewardLength >= 1) {
            _extraReward1 = IRewards(IBaseRewardPool(_baseRewardPool).extraRewards(0)).rewardToken();

            if (extraRewardLength >= 2) {
                _extraReward2 = IRewards(IBaseRewardPool(_baseRewardPool).extraRewards(1)).rewardToken();
            }
        }

        mask = _extraReward1 != address(0) ? creditManager.tokenMasksMap(_extraReward1) : 0;
        if (_extraReward1 != address(0) && mask == 0) {
            revert TokenIsNotInAllowedList(_extraReward1); // F: [ACVX1_P-2]
        }
        _rewardTokensMask |= mask;

        mask = _extraReward2 != address(0) ? creditManager.tokenMasksMap(_extraReward2) : 0;
        if (_extraReward2 != address(0) && mask == 0) {
            revert TokenIsNotInAllowedList(_extraReward2); // F: [ACVX1_P-2]
        }
        _rewardTokensMask |= mask;

        rewardTokensMask = _rewardTokensMask; // F: [ACVX1_P-1]
    }

    /// ----- ///
    /// STAKE ///
    /// ----- ///

    /// @notice Stakes Convex LP token in the reward pool
    /// @dev `amount` parameter is ignored since calldata is passed directly to the target contract
    function stake(uint256) external override creditFacadeOnly {
        _stake(msg.data, false); // F: [ACVX1_P-3]
    }

    /// @notice Stakes the entire balance of Convex LP token in the reward pool, disables LP token
    function stakeAll() external override creditFacadeOnly {
        _stake(msg.data, true); // F: [ACVX1_P-4]
    }

    /// @dev Internal implementation of `stake` and `stakeAll`
    ///      - Staking token is approved because reward pool needs permission to transfer it
    ///      - Staked token is enabled after the call
    ///      - Staking token is only disabled when staking the entire balance
    function _stake(bytes memory callData, bool disableStakingToken) internal {
        _approveToken(stakingToken, type(uint256).max);
        _execute(callData);
        _approveToken(stakingToken, 1);
        _changeEnabledTokens(stakedTokenMask, disableStakingToken ? stakingTokenMask : 0);
    }

    /// ----- ///
    /// CLAIM ///
    /// ----- ///

    /// @notice Claims rewards on the current position, enables reward tokens
    function getReward() external override creditFacadeOnly {
        _execute(msg.data); // F: [ACVX1_P-5]
        _changeEnabledTokens(rewardTokensMask, 0); // F: [ACVX1_P-5]
    }

    /// -------- ///
    /// WITHDRAW ///
    /// -------- ///

    /// @notice Withdraws Convex LP token from the reward pool
    /// @param claim Whether to claim staking rewards
    /// @dev `amount` parameter is ignored since calldata is passed directly to the target contract
    function withdraw(uint256, bool claim) external override creditFacadeOnly {
        _withdraw(msg.data, claim, false); // F: [ACVX1_P-6]
    }

    /// @notice Withdraws the entire balance of Convex LP token from the reward pool, disables staked token
    /// @param claim Whether to claim staking rewards
    function withdrawAll(bool claim) external override creditFacadeOnly {
        _withdraw(msg.data, claim, true); // F: [ACVX1_P-7]
    }

    /// @dev Internal implementation of `withdraw` and `withdrawAll`
    ///      - Staking token is enabled after the call
    ///      - Staked token is only disabled when withdrawing the entire balance
    ///      - Rewards tokens are enabled if `claim` is true
    function _withdraw(bytes memory callData, bool claim, bool disableStakedToken) internal {
        _execute(callData);
        _changeEnabledTokens(
            stakingTokenMask | (claim ? rewardTokensMask : 0), disableStakedToken ? stakedTokenMask : 0
        );
    }

    /// ------ ///
    /// UNWRAP ///
    /// ------ ///

    /// @notice Withdraws Convex LP token from the reward pool and unwraps it into Curve LP token
    /// @param claim Whether to claim staking rewards
    /// @dev `amount` parameter is ignored since calldata is passed directly to the target contract
    function withdrawAndUnwrap(uint256, bool claim) external override creditFacadeOnly {
        _withdrawAndUnwrap(msg.data, claim, false); // F: [ACVX1_P-8]
    }

    /// @notice Withdraws the entire balance of Convex LP token from the reward pool and unwraps it into Curve LP token,
    ///         disables staked token
    /// @param claim Whether to claim staking rewards
    function withdrawAllAndUnwrap(bool claim) external override creditFacadeOnly {
        _withdrawAndUnwrap(msg.data, claim, true); // F: [ACVX1_P-9]
    }

    /// @dev Internal implementation of `withdrawAndUnwrap` and `withdrawAllAndUnwrap`
    ///      - Curve LP token is enabled after the call
    ///      - Staked token is only disabled when withdrawing the entire balance
    ///      - Rewards tokens are enabled if `claim` is true
    function _withdrawAndUnwrap(bytes memory callData, bool claim, bool disableStakedToken) internal {
        _execute(callData);
        _changeEnabledTokens(
            curveLPTokenMask | (claim ? rewardTokensMask : 0), disableStakedToken ? stakedTokenMask : 0
        );
    }
}
