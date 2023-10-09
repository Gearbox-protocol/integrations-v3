// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";
import {BitMask} from "@gearbox-protocol/core-v3/contracts/libraries/BitMask.sol";

import {IBooster} from "../../integrations/convex/IBooster.sol";
import {IBaseRewardPool} from "../../integrations/convex/IBaseRewardPool.sol";
import {IRewards, IExtraRewardWrapper} from "../../integrations/convex/Interfaces.sol";
import {IConvexV1BaseRewardPoolAdapter} from "../../interfaces/convex/IConvexV1BaseRewardPoolAdapter.sol";

/// @title Convex V1 BaseRewardPool adapter interface
/// @notice Implements logic for interacting with Convex reward pool
contract ConvexV1BaseRewardPoolAdapter is AbstractAdapter, IConvexV1BaseRewardPoolAdapter {
    using BitMask for uint256;

    AdapterType public constant override _gearboxAdapterType = AdapterType.CONVEX_V1_BASE_REWARD_POOL;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

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

    /// @notice Reward paid by the extra reward pool 1 (address(0) if none)
    address public immutable override extraReward1;

    /// @notice Reward paid by the extra reward pool 2 (address(0) if none)
    address public immutable override extraReward2;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _baseRewardPool BaseRewardPool address
    /// @param _stakedPhantomToken Reward pool stake token address
    constructor(address _creditManager, address _baseRewardPool, address _stakedPhantomToken)
        AbstractAdapter(_creditManager, _baseRewardPool)
    {
        stakingToken = address(IBaseRewardPool(_baseRewardPool).stakingToken()); // F: [ACVX1_P-1]
        stakingTokenMask = _getMaskOrRevert(stakingToken); // F: [ACVX1_P-1, ACVX1_P-2]

        stakedPhantomToken = _stakedPhantomToken; // F: [ACVX1_P-1]
        stakedTokenMask = _getMaskOrRevert(stakedPhantomToken); // F: [ACVX1_P-1, ACVX1_P-2]

        address booster = IBaseRewardPool(_baseRewardPool).operator();
        IBooster.PoolInfo memory poolInfo = IBooster(booster).poolInfo(IBaseRewardPool(_baseRewardPool).pid());
        curveLPtoken = poolInfo.lptoken; // F: [ACVX1_P-1]
        curveLPTokenMask = _getMaskOrRevert(curveLPtoken); // F: [ACVX1_P-1, ACVX1_P-2]

        uint256 _rewardTokensMask;

        address rewardToken = address(IBaseRewardPool(_baseRewardPool).rewardToken());
        _rewardTokensMask = _rewardTokensMask.enable(_getMaskOrRevert(rewardToken)); // F: [ACVX1_P-2]

        address cvx = IBooster(booster).minter();
        _rewardTokensMask = _rewardTokensMask.enable(_getMaskOrRevert(cvx)); // F: [ACVX1_P-2]

        address _extraReward1;
        address _extraReward2;
        uint256 extraRewardLength = IBaseRewardPool(_baseRewardPool).extraRewardsLength();

        if (extraRewardLength >= 1) {
            _extraReward1 = IRewards(IBaseRewardPool(_baseRewardPool).extraRewards(0)).rewardToken();

            try ICreditManagerV3(creditManager).getTokenMaskOrRevert(_extraReward1) returns (uint256) {}
            catch {
                _extraReward1 = IExtraRewardWrapper(_extraReward1).token();
            }

            if (extraRewardLength >= 2) {
                _extraReward2 = IRewards(IBaseRewardPool(_baseRewardPool).extraRewards(1)).rewardToken();

                try ICreditManagerV3(creditManager).getTokenMaskOrRevert(_extraReward2) returns (uint256) {}
                catch {
                    _extraReward2 = IExtraRewardWrapper(_extraReward2).token();
                }
            }
        }

        extraReward1 = _extraReward1;
        extraReward2 = _extraReward2;

        if (_extraReward1 != address(0)) _rewardTokensMask = _rewardTokensMask.enable(_getMaskOrRevert(_extraReward1)); // F: [ACVX1_P-2]
        if (_extraReward2 != address(0)) _rewardTokensMask = _rewardTokensMask.enable(_getMaskOrRevert(_extraReward2)); // F: [ACVX1_P-2]

        rewardTokensMask = _rewardTokensMask; // F: [ACVX1_P-1]
    }

    // ----- //
    // STAKE //
    // ----- //

    /// @notice Stakes Convex LP token in the reward pool
    /// @dev `amount` parameter is ignored since calldata is passed directly to the target contract
    function stake(uint256)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _stake(msg.data, false); // F: [ACVX1_P-3]
    }

    /// @notice Stakes the entire balance of Convex LP token in the reward pool, disables LP token
    function stakeAll() external override creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        (tokensToEnable, tokensToDisable) = _stake(msg.data, true); // F: [ACVX1_P-4]
    }

    /// @dev Internal implementation of `stake` and `stakeAll`
    ///      - Staking token is approved because reward pool needs permission to transfer it
    ///      - Staked token is enabled after the call
    ///      - Staking token is only disabled when staking the entire balance
    function _stake(bytes memory callData, bool disableStakingToken)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approveToken(stakingToken, type(uint256).max);
        _execute(callData);
        _approveToken(stakingToken, 1);
        (tokensToEnable, tokensToDisable) = (stakedTokenMask, disableStakingToken ? stakingTokenMask : 0);
    }

    // ----- //
    // CLAIM //
    // ----- //

    /// @notice Claims rewards on the current position, enables reward tokens
    function getReward() external override creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        _execute(msg.data); // F: [ACVX1_P-5]
        (tokensToEnable, tokensToDisable) = (rewardTokensMask, 0); // F: [ACVX1_P-5]
    }

    // -------- //
    // WITHDRAW //
    // -------- //

    /// @notice Withdraws Convex LP token from the reward pool
    /// @param claim Whether to claim staking rewards
    /// @dev `amount` parameter is ignored since calldata is passed directly to the target contract
    function withdraw(uint256, bool claim)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdraw(msg.data, claim, false); // F: [ACVX1_P-6]
    }

    /// @notice Withdraws the entire balance of Convex LP token from the reward pool, disables staked token
    /// @param claim Whether to claim staking rewards
    function withdrawAll(bool claim)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdraw(msg.data, claim, true); // F: [ACVX1_P-7]
    }

    /// @dev Internal implementation of `withdraw` and `withdrawAll`
    ///      - Staking token is enabled after the call
    ///      - Staked token is only disabled when withdrawing the entire balance
    ///      - Rewards tokens are enabled if `claim` is true
    function _withdraw(bytes memory callData, bool claim, bool disableStakedToken)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(callData);
        (tokensToEnable, tokensToDisable) =
            (stakingTokenMask.enable(claim ? rewardTokensMask : 0), disableStakedToken ? stakedTokenMask : 0);
    }

    // ------ //
    // UNWRAP //
    // ------ //

    /// @notice Withdraws Convex LP token from the reward pool and unwraps it into Curve LP token
    /// @param claim Whether to claim staking rewards
    /// @dev `amount` parameter is ignored since calldata is passed directly to the target contract
    function withdrawAndUnwrap(uint256, bool claim)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdrawAndUnwrap(msg.data, claim, false); // F: [ACVX1_P-8]
    }

    /// @notice Withdraws the entire balance of Convex LP token from the reward pool and unwraps it into Curve LP token,
    ///         disables staked token
    /// @param claim Whether to claim staking rewards
    function withdrawAllAndUnwrap(bool claim)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdrawAndUnwrap(msg.data, claim, true); // F: [ACVX1_P-9]
    }

    /// @dev Internal implementation of `withdrawAndUnwrap` and `withdrawAllAndUnwrap`
    ///      - Curve LP token is enabled after the call
    ///      - Staked token is only disabled when withdrawing the entire balance
    ///      - Rewards tokens are enabled if `claim` is true
    function _withdrawAndUnwrap(bytes memory callData, bool claim, bool disableStakedToken)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(callData);
        (tokensToEnable, tokensToDisable) =
            (curveLPTokenMask.enable(claim ? rewardTokensMask : 0), disableStakedToken ? stakedTokenMask : 0);
    }
}
