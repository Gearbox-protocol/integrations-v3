// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {AdapterType} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";
import {AbstractAdapter} from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";

import {IBooster} from "../../integrations/convex/IBooster.sol";
import {IBaseRewardPool} from "../../integrations/convex/IBaseRewardPool.sol";
import {IRewards} from "../../integrations/convex/Interfaces.sol";
import {IConvexV1BaseRewardPoolAdapter} from "../../interfaces/convex/IConvexV1BaseRewardPoolAdapter.sol";

/// @title ConvexV1BaseRewardPoolAdapter adapter
/// @dev Implements logic for interacting with the Convex BaseRewardPool contract
contract ConvexV1BaseRewardPoolAdapter is AbstractAdapter, IConvexV1BaseRewardPoolAdapter {
    /// @dev The underlying Curve pool LP token
    address public immutable override curveLPtoken;

    /// @dev A non-transferable ERC20 that reports the amount of Convex LP staked in the pool
    address public immutable override stakedPhantomToken;

    /// @dev The first token received as an extra reward for staking
    address public immutable override extraReward1;

    /// @dev The second token received as an extra reward for staking
    address public immutable override extraReward2;

    /// @dev The CVX token, received as a reward for staking
    address public immutable override cvx;

    /// @dev The pid of baseRewardPool
    uint256 public immutable override pid;

    /// @dev Returns the token that is paid as a reward to stakers
    /// @notice This is always CRV
    address public immutable override rewardToken;

    /// @dev Returns the token that is staked in the pool
    address public immutable override stakingToken;

    AdapterType public constant _gearboxAdapterType = AdapterType.CONVEX_V1_BASE_REWARD_POOL;
    uint16 public constant _gearboxAdapterVersion = 2;

    /// @dev Constructor
    /// @param _creditManager Address of the Credit Manager
    /// @param _baseRewardPool Address of the target BaseRewardPool contract
    constructor(address _creditManager, address _baseRewardPool, address _stakedPhantomToken)
        AbstractAdapter(_creditManager, _baseRewardPool)
    {
        stakingToken = address(IBaseRewardPool(_baseRewardPool).stakingToken()); // F: [ACVX1_P-1]

        pid = IBaseRewardPool(_baseRewardPool).pid(); // F: [ACVX1_P-1]

        rewardToken = address(IBaseRewardPool(_baseRewardPool).rewardToken()); // F: [ACVX1_P-1]

        stakedPhantomToken = _stakedPhantomToken;

        address _extraReward1;
        address _extraReward2;

        uint256 extraRewardLength = IBaseRewardPool(_baseRewardPool).extraRewardsLength();

        if (extraRewardLength >= 1) {
            _extraReward1 = IRewards(IBaseRewardPool(_baseRewardPool).extraRewards(0)).rewardToken();

            if (extraRewardLength >= 2) {
                _extraReward2 = IRewards(IBaseRewardPool(_baseRewardPool).extraRewards(1)).rewardToken();
            }
        }

        extraReward1 = _extraReward1; // F: [ACVX1_P-1]
        extraReward2 = _extraReward2; // F: [ACVX1_P-1]

        address booster = IBaseRewardPool(_baseRewardPool).operator();

        cvx = IBooster(booster).minter(); // F: [ACVX1_P-1]
        IBooster.PoolInfo memory poolInfo = IBooster(booster).poolInfo(IBaseRewardPool(_baseRewardPool).pid());

        curveLPtoken = poolInfo.lptoken; // F: [ACVX1_P-1]

        if (creditManager.tokenMasksMap(rewardToken) == 0) {
            revert TokenIsNotInAllowedList(rewardToken);
        } // F: [ACVX1_P-2]

        if (creditManager.tokenMasksMap(cvx) == 0) {
            revert TokenIsNotInAllowedList(cvx);
        } // F: [ACVX1_P-2]

        if (creditManager.tokenMasksMap(curveLPtoken) == 0) {
            revert TokenIsNotInAllowedList(curveLPtoken);
        } // F: [ACVX1_P-2]

        if (_extraReward1 != address(0) && creditManager.tokenMasksMap(_extraReward1) == 0) {
            revert TokenIsNotInAllowedList(_extraReward1);
        } // F: [ACVX1_P-2]

        if (_extraReward2 != address(0) && creditManager.tokenMasksMap(_extraReward2) == 0) {
            revert TokenIsNotInAllowedList(_extraReward2);
        } // F: [ACVX1_P-2]
    }

    /// @dev Sends an order to stake Convex LP tokens in the BaseRewardPool
    /// @notice 'amount' is ignored since the calldata is routed directly to the target
    /// @notice Fast check parameters:
    /// Input token: Convex LP Token
    /// Output token: Phantom token (representing staked balance in the pool)
    /// Input token is allowed, since the target does a transferFrom for the Convex LP token
    /// The input token does not need to be disabled, because this does not spend the entire
    /// balance generally
    function stake(uint256) external override creditFacadeOnly {
        _executeSwapSafeApprove(stakingToken, stakedPhantomToken, msg.data, false); // F: [ACVX1_P-3]
    }

    /// @dev Sends an order to stake all available Convex LP tokens in the BaseRewardPool
    /// @notice Fast check parameters:
    /// Input token: Convex LP Token
    /// Output token: Phantom token (representing staked balance in the pool)
    /// Input token is allowed, since the target does a transferFrom for the Convex LP token
    /// The input token does need to be disabled, because this spends the entire balance
    function stakeAll() external override creditFacadeOnly {
        _executeSwapSafeApprove(stakingToken, stakedPhantomToken, msg.data, true); // F: [ACVX1_P-4]
    }

    /// @dev Sends an order to withdraw Convex LP tokens from the BaseRewardPool
    /// @param claim Whether to claim rewards while withdrawing
    /// @notice 'amount' is ignored since the unchanged calldata is routed directly to the target
    /// The input token does not need to be disabled, because this does not spend the entire
    /// balance generally
    function withdraw(uint256, bool claim) external override creditFacadeOnly {
        _withdraw(msg.data, claim, false); // F: [ACVX1_P-6]
    }

    /// @dev Sends an order to withdraw all Convex LP tokens from the BaseRewardPool
    /// @param claim Whether to claim rewards while withdrawing
    /// The input token does need to be disabled, because this spends the entire balance
    function withdrawAll(bool claim) external override creditFacadeOnly {
        _withdraw(msg.data, claim, true); // F: [ACVX1_P-7]
    }

    /// @dev Internal implementation for withdrawal functions
    /// - Invokes a safe allowance fast check call to target, with passed calldata
    /// - Enables reward tokens if rewards were claimed
    /// @param callData Data that the target contract will be called with
    /// @param claim Whether to claim rewards while withdrawing
    /// @notice Fast check parameters:
    /// Input token: Phantom token (representing staked balance in the pool)
    /// Output token: Convex LP Token
    /// Input token is not allowed, since the target does not need to transferFrom
    function _withdraw(bytes memory callData, bool claim, bool disableTokenIn) internal {
        address creditAccount = _creditAccount();

        _executeSwapNoApprove(creditAccount, stakedPhantomToken, stakingToken, callData, disableTokenIn);

        if (claim) {
            _enableRewardTokens(creditAccount);
        }
    }

    /// @dev Sends an order to withdraw Convex LP tokens from the BaseRewardPool
    /// and immediately unwrap them into Curve LP tokens
    /// @param claim Whether to claim rewards while withdrawing
    /// @notice 'amount' is ignored since the unchanged calldata is routed directly to the target
    /// The input token does not need to be disabled, because this does not spend the entire
    /// balance generally
    function withdrawAndUnwrap(uint256, bool claim) external override creditFacadeOnly {
        _withdrawAndUnwrap(msg.data, claim, false); // F: [ACVX1_P-8]
    }

    /// @dev Sends an order to withdraw all Convex LP tokens from the BaseRewardPool
    /// and immediately unwrap them into Curve LP tokens
    /// @param claim Whether to claim rewards while withdrawing
    /// The input token does need to be disabled, because this spends the entire balance
    function withdrawAllAndUnwrap(bool claim) external override creditFacadeOnly {
        _withdrawAndUnwrap(msg.data, claim, true); // F: [ACVX1_P-9]
    }

    /// @dev Internal implementation for 'withdrawAndUnwrap' functions
    /// - Invokes a safe allowance fast check call to target, with passed calldata
    /// - Enables reward tokens if rewards were claimed
    /// @param callData Data that the target contract will be called with
    /// @param claim Whether to claim rewards while withdrawing
    /// @notice Fast check parameters:
    /// Input token: Phantom token (representing staked balance in the pool)
    /// Output token: Curve LP Token
    /// Input token is not allowed, since the target does not need to transferFrom
    function _withdrawAndUnwrap(bytes memory callData, bool claim, bool disableTokenIn) internal {
        address creditAccount = _creditAccount();

        _executeSwapNoApprove(creditAccount, stakedPhantomToken, curveLPtoken, callData, disableTokenIn);

        if (claim) {
            _enableRewardTokens(creditAccount);
        }
    }

    /// @dev Sends an order to harvest rewards on the current position
    /// - Routes calldata to the target contract
    /// - Enables the reward tokens that are harvested
    function getReward() external override creditFacadeOnly {
        address creditAccount = _creditAccount();

        _execute(msg.data); // F: [ACVX1_P-5]

        _enableRewardTokens(creditAccount);
    }

    /// @dev Enables reward tokens for a credit account after a claim operation
    /// @param creditAccount The credit account on which reward tokens are enabled
    function _enableRewardTokens(address creditAccount) internal {
        // F: [ACVX1_P_3-9]
        creditManager.checkAndEnableToken(creditAccount, rewardToken);
        creditManager.checkAndEnableToken(creditAccount, cvx);

        if ((extraReward1 != address(0))) {
            // F: [ACVX1_P-5]
            creditManager.checkAndEnableToken(creditAccount, extraReward1);

            if (extraReward2 != address(0)) {
                creditManager.checkAndEnableToken(creditAccount, extraReward2);
            }
        }
    }
}
