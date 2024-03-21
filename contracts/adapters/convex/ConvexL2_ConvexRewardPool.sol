// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";
import {BitMask} from "@gearbox-protocol/core-v3/contracts/libraries/BitMask.sol";

import {IBooster_L2} from "../../integrations/convex/IBooster_L2.sol";
import {IConvexRewardPool_L2} from "../../integrations/convex/IConvexRewardPool_L2.sol";
import {IConvexL2RewardPoolAdapter} from "../../interfaces/convex/IConvexL2RewardPoolAdapter.sol";

/// @title Convex L2 ConvexRewardPool adapter interface
/// @notice Implements logic for interacting with L2 implementation of Convex reward pools
contract ConvexL2RewardPoolAdapter is AbstractAdapter, IConvexL2RewardPoolAdapter {
    using BitMask for uint256;

    AdapterType public constant override _gearboxAdapterType = AdapterType.CONVEX_L2_REWARD_POOL;
    uint16 public constant override _gearboxAdapterVersion = 3_01;

    /// @notice Address of a Curve LP token deposited into the Convex pool
    address public immutable override curveLPtoken;

    /// @notice Address of the first reward token in the pool
    address public immutable override reward0;

    /// @notice Address of the second reward token in the pool
    address public immutable override reward1;

    /// @notice Address of the third reward token in the pool, if any
    address public immutable override reward2;

    /// @notice Address of the fourth reward token in the pool, if any
    address public immutable override reward3;

    /// @notice Address of the fifth reward token in the pool, if any
    address public immutable override reward4;

    /// @notice Address of the sixth reward token in the pool, if any
    address public immutable override reward5;

    /// @notice Collateral token mask of a Curve LP token in the credit manager
    uint256 public immutable override curveLPTokenMask;

    /// @notice Collateral token mask of a Convex LP token in the credit manager
    uint256 public immutable override convexPoolTokenMask;

    /// @notice Bitmask of all reward tokens of the pool (CRV, CVX, extra reward tokens, if any) in the credit manager
    uint256 public immutable override rewardTokensMask;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _convexRewardPool ConvexRewardPool address
    constructor(address _creditManager, address _convexRewardPool) AbstractAdapter(_creditManager, _convexRewardPool) {
        address booster = IConvexRewardPool_L2(_convexRewardPool).convexBooster();
        (curveLPtoken,,,,) = IBooster_L2(booster).poolInfo(IConvexRewardPool_L2(_convexRewardPool).convexPoolId());
        curveLPTokenMask = _getMaskOrRevert(curveLPtoken);

        convexPoolTokenMask = _getMaskOrRevert(_convexRewardPool);

        uint256 _rewardTokensMask;

        uint256 rewardsLength = IConvexRewardPool_L2(_convexRewardPool).rewardLength();

        reward0 = IConvexRewardPool_L2(_convexRewardPool).rewards(0).reward_token;
        reward1 = IConvexRewardPool_L2(_convexRewardPool).rewards(1).reward_token;

        _rewardTokensMask = _rewardTokensMask.enable(_getMaskOrRevert(reward0)).enable(_getMaskOrRevert(reward1));

        address _reward2;
        address _reward3;
        address _reward4;
        address _reward5;

        if (rewardsLength >= 3) {
            _reward2 = IConvexRewardPool_L2(_convexRewardPool).rewards(2).reward_token;
            _rewardTokensMask = _rewardTokensMask.enable(_getMaskOrRevert(_reward2));

            if (rewardsLength >= 4) {
                _reward3 = IConvexRewardPool_L2(_convexRewardPool).rewards(3).reward_token;
                _rewardTokensMask = _rewardTokensMask.enable(_getMaskOrRevert(_reward3));

                if (rewardsLength >= 5) {
                    _reward4 = IConvexRewardPool_L2(_convexRewardPool).rewards(4).reward_token;
                    _rewardTokensMask = _rewardTokensMask.enable(_getMaskOrRevert(_reward4));

                    if (rewardsLength >= 6) {
                        _reward5 = IConvexRewardPool_L2(_convexRewardPool).rewards(5).reward_token;
                        _rewardTokensMask = _rewardTokensMask.enable(_getMaskOrRevert(_reward4));
                    }
                }
            }
        }

        reward2 = _reward2;
        reward3 = _reward3;
        reward4 = _reward4;
        reward5 = _reward5;
        rewardTokensMask = _rewardTokensMask;
    }

    // ----- //
    // CLAIM //
    // ----- //

    function getReward() external override creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        address creditAccount = _creditAccount();
        _execute(abi.encodeCall(IConvexRewardPool_L2.getReward, (creditAccount)));
        (tokensToEnable, tokensToDisable) = (rewardTokensMask, 0);
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
        (tokensToEnable, tokensToDisable) = _withdraw(msg.data, claim, false);
    }

    /// @notice Withdraws the entire balance of Convex LP token from the reward pool, except the specified amount
    /// @param leftoverAmount Amount of staked Convex LP to keep on the account
    /// @param claim Whether to claim staking rewards
    function withdrawDiff(uint256 leftoverAmount, bool claim)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();

        uint256 balance = IERC20(targetContract).balanceOf(creditAccount);

        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) = _withdraw(
                    abi.encodeCall(IConvexRewardPool_L2.withdraw, (balance - leftoverAmount, claim)),
                    claim,
                    leftoverAmount <= 1
                );
            }
        }
    }

    /// @dev Internal implementation of `withdraw` and `withdrawDiff`
    ///      - Curve LP is enabled after the call
    ///      - Convex pool is only disabled when withdrawing the entire balance
    ///      - Rewards tokens are enabled if `claim` is true
    function _withdraw(bytes memory callData, bool claim, bool disableConvexPoolToken)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(callData); // U:[CVX1R-7,8]
        (tokensToEnable, tokensToDisable) =
            (curveLPTokenMask.enable(claim ? rewardTokensMask : 0), disableConvexPoolToken ? convexPoolTokenMask : 0);
    }
}
