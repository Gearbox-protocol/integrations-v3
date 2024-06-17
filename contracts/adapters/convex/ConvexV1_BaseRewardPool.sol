// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";
import {BitMask} from "@gearbox-protocol/core-v3/contracts/libraries/BitMask.sol";

import {IBooster} from "../../integrations/convex/IBooster.sol";
import {IBaseRewardPool} from "../../integrations/convex/IBaseRewardPool.sol";
import {IRewards, IExtraRewardWrapper, IAuraL2Coordinator} from "../../integrations/convex/Interfaces.sol";
import {IConvexV1BaseRewardPoolAdapter} from "../../interfaces/convex/IConvexV1BaseRewardPoolAdapter.sol";

/// @title Convex V1 BaseRewardPool adapter interface
/// @notice Implements logic for interacting with Convex reward pool
contract ConvexV1BaseRewardPoolAdapter is AbstractAdapter, IConvexV1BaseRewardPoolAdapter {
    using BitMask for uint256;

    AdapterType public constant override _gearboxAdapterType = AdapterType.CONVEX_V1_BASE_REWARD_POOL;
    uint16 public constant override _gearboxAdapterVersion = 3_10;

    /// @notice Address of a Curve LP token deposited into the Convex pool
    address public immutable override curveLPtoken;

    /// @notice Address of a Convex LP token staked in the reward pool
    address public immutable override stakingToken;

    /// @notice Address of a phantom token representing account's stake in the reward pool
    address public immutable override stakedPhantomToken;

    /// @notice Address of a reward token of the first extra reward pool, if any
    address public immutable override extraReward1;

    /// @notice Address of a reward token of the second extra reward pool, if any
    address public immutable override extraReward2;

    /// @notice Address of a reward token of the third extra reward pool, if any
    address public immutable override extraReward3;

    /// @notice Address of a reward token of the fourth extra reward pool, if any
    address public immutable override extraReward4;

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
        AbstractAdapter(_creditManager, _baseRewardPool) // U:[CVX1R-1]
    {
        stakingToken = address(IBaseRewardPool(_baseRewardPool).stakingToken()); // U:[CVX1R-1]
        stakingTokenMask = _getMaskOrRevert(stakingToken); // U:[CVX1R-1]

        stakedPhantomToken = _stakedPhantomToken; // U:[CVX1R-1]
        stakedTokenMask = _getMaskOrRevert(stakedPhantomToken); // U:[CVX1R-1]

        address booster = IBaseRewardPool(_baseRewardPool).operator();
        IBooster.PoolInfo memory poolInfo = IBooster(booster).poolInfo(IBaseRewardPool(_baseRewardPool).pid());
        curveLPtoken = poolInfo.lptoken; // U:[CVX1R-1]
        curveLPTokenMask = _getMaskOrRevert(curveLPtoken); // U:[CVX1R-1]

        uint256 _rewardTokensMask;

        address rewardToken = address(IBaseRewardPool(_baseRewardPool).rewardToken());
        _rewardTokensMask = _rewardTokensMask.enable(_getMaskOrRevert(rewardToken)); // U:[CVX1R-1]

        _rewardTokensMask = _rewardTokensMask.enable(_getSecondaryRewardMask(booster)); // U:[CVX1R-1]

        address _extraReward1;
        address _extraReward2;
        address _extraReward3;
        address _extraReward4;
        uint256 extraRewardLength = IBaseRewardPool(_baseRewardPool).extraRewardsLength();

        if (extraRewardLength >= 1) {
            uint256 _extraRewardMask;
            (_extraReward1, _extraRewardMask) = _getExtraReward(0);
            _rewardTokensMask = _rewardTokensMask.enable(_extraRewardMask);

            if (extraRewardLength >= 2) {
                (_extraReward2, _extraRewardMask) = _getExtraReward(1);
                _rewardTokensMask = _rewardTokensMask.enable(_extraRewardMask);

                if (extraRewardLength >= 3) {
                    (_extraReward3, _extraRewardMask) = _getExtraReward(2);
                    _rewardTokensMask = _rewardTokensMask.enable(_extraRewardMask);

                    if (extraRewardLength >= 4) {
                        (_extraReward4, _extraRewardMask) = _getExtraReward(3);
                        _rewardTokensMask = _rewardTokensMask.enable(_extraRewardMask);
                    }
                }
            }
        }

        extraReward1 = _extraReward1; // U:[CVX1R-2]
        extraReward2 = _extraReward2; // U:[CVX1R-2]
        extraReward3 = _extraReward3;
        extraReward4 = _extraReward4;
        rewardTokensMask = _rewardTokensMask; // U:[CVX1R-2]
    }

    /// @dev Returns `i`-th extra reward token and its collateral mask in the credit mnager
    function _getExtraReward(uint256 i) internal view returns (address extraReward, uint256 extraRewardMask) {
        extraReward = IRewards(IBaseRewardPool(targetContract).extraRewards(i)).rewardToken();

        // `extraReward` might be a wrapper around the reward token, and there seems to be no reliable way to check it
        // programatically, so we assume that it's a wrapper if it's not recognized as collateral in the credit manager
        try ICreditManagerV3(creditManager).getTokenMaskOrRevert(extraReward) returns (uint256 mask) {
            extraRewardMask = mask;
        } catch {
            try IExtraRewardWrapper(extraReward).token() returns (address baseToken) {
                extraReward = baseToken;
            } catch {
                extraReward = IExtraRewardWrapper(extraReward).baseToken();
            }
            extraRewardMask = _getMaskOrRevert(extraReward);
        }
    }

    /// @dev Aura on L2 networks can have a different contract instead of the secondary reward token
    ///      in IBooster.minter(). If the minter is not recognized as collateral in CM, we assume that
    ///      it is not the secondary reward and handle the situation
    function _getSecondaryRewardMask(address booster) internal view returns (uint256 rewardMask) {
        address reward = IBooster(booster).minter();

        try ICreditManagerV3(creditManager).getTokenMaskOrRevert(reward) returns (uint256 mask) {
            rewardMask = mask;
        } catch {
            reward = IAuraL2Coordinator(reward).auraOFT();
            rewardMask = _getMaskOrRevert(reward);
        }
    }

    // ----- //
    // STAKE //
    // ----- //

    /// @notice Stakes Convex LP token in the reward pool
    /// @dev `amount` parameter is ignored since calldata is passed directly to the target contract
    function stake(uint256)
        external
        override
        creditFacadeOnly // U:[CVX1R-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _stake(msg.data, false); // U:[CVX1R-4]
    }

    /// @notice Stakes the entire balance of Convex LP token in the reward pool, except the specified amount
    /// @param leftoverAmount Amount of Convex LP to keep on the account
    function stakeDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[CVX1R-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[CVX1R-5]

        uint256 balance = IERC20(stakingToken).balanceOf(creditAccount); // U:[CVX1R-5]

        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) =
                    _stake(abi.encodeCall(IBaseRewardPool.stake, (balance - leftoverAmount)), leftoverAmount <= 1); // U:[CVX1R-5]
            }
        }
    }

    /// @dev Internal implementation of `stake` and `stakeDiff`
    ///      - Staking token is approved because reward pool needs permission to transfer it
    ///      - Staked token is enabled after the call
    ///      - Staking token is only disabled when staking the entire balance
    function _stake(bytes memory callData, bool disableStakingToken)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approveToken(stakingToken, type(uint256).max); // U:[CVX1R-4,5]
        _execute(callData); // U:[CVX1R-4,5]
        _approveToken(stakingToken, 1); // U:[CVX1R-4,5]
        (tokensToEnable, tokensToDisable) = (stakedTokenMask, disableStakingToken ? stakingTokenMask : 0);
    }

    // ----- //
    // CLAIM //
    // ----- //

    /// @notice Claims rewards on the current position, enables reward tokens
    function getReward()
        external
        override
        creditFacadeOnly // U:[CVX1R-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(msg.data); // U:[CVX1R-6]
        (tokensToEnable, tokensToDisable) = (rewardTokensMask, 0); // U:[CVX1R-6]
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
        creditFacadeOnly // U:[CVX1R-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdraw(msg.data, claim, false); // U:[CVX1R-7]
    }

    /// @notice Withdraws the entire balance of Convex LP token from the reward pool, except the specified amount
    /// @param leftoverAmount Amount of staked Convex LP to keep on the account
    /// @param claim Whether to claim staking rewards
    function withdrawDiff(uint256 leftoverAmount, bool claim)
        external
        override
        creditFacadeOnly // U:[CVX1R-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[CVX1R-6]

        uint256 balance = IERC20(stakedPhantomToken).balanceOf(creditAccount); // U:[CVX1R-6]

        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) = _withdraw(
                    abi.encodeCall(IBaseRewardPool.withdraw, (balance - leftoverAmount, claim)),
                    claim,
                    leftoverAmount <= 1
                ); // U:[CVX1R-6]
            }
        }
    }

    /// @dev Internal implementation of `withdraw` and `withdrawDiff`
    ///      - Staking token is enabled after the call
    ///      - Staked token is only disabled when withdrawing the entire balance
    ///      - Rewards tokens are enabled if `claim` is true
    function _withdraw(bytes memory callData, bool claim, bool disableStakedToken)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(callData); // U:[CVX1R-7,8]
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
        creditFacadeOnly // U:[CVX1R-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdrawAndUnwrap(msg.data, claim, false); // U:[CVX1R-9]
    }

    /// @notice Withdraws the entire balance of Convex LP token from the reward pool, except the specified amount
    ///         disables staked token
    /// @param leftoverAmount Amount of staked token to keep on the account
    /// @param claim Whether to claim staking rewards
    function withdrawDiffAndUnwrap(uint256 leftoverAmount, bool claim)
        external
        override
        creditFacadeOnly // U:[CVX1R-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[CVX1R-10]

        uint256 balance = IERC20(stakedPhantomToken).balanceOf(creditAccount); // U:[CVX1R-10]

        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) = _withdrawAndUnwrap(
                    abi.encodeCall(IBaseRewardPool.withdrawAndUnwrap, (balance - leftoverAmount, claim)),
                    claim,
                    leftoverAmount <= 1
                ); // U:[CVX1R-10]
            }
        }
    }

    /// @dev Internal implementation of `withdrawAndUnwrap` and `withdrawDiffAndUnwrap`
    ///      - Curve LP token is enabled after the call
    ///      - Staked token is only disabled when withdrawing the entire balance
    ///      - Rewards tokens are enabled if `claim` is true
    function _withdrawAndUnwrap(bytes memory callData, bool claim, bool disableStakedToken)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(callData); // U:[CVX1R-9,10]
        (tokensToEnable, tokensToDisable) =
            (curveLPTokenMask.enable(claim ? rewardTokensMask : 0), disableStakedToken ? stakedTokenMask : 0);
    }

    /// @notice Returns all adapter parameters serialized into a bytes array,
    ///         as well as adapter type and version, to properly deserialize
    function serialize() external view returns (AdapterType, uint16, bytes[] memory) {
        bytes[] memory serializedData = new bytes[](13);
        serializedData[0] = abi.encode(creditManager);
        serializedData[1] = abi.encode(targetContract);
        serializedData[2] = abi.encode(curveLPtoken);
        serializedData[3] = abi.encode(stakingToken);
        serializedData[4] = abi.encode(stakedPhantomToken);
        serializedData[5] = abi.encode(extraReward1);
        serializedData[6] = abi.encode(extraReward2);
        serializedData[7] = abi.encode(extraReward3);
        serializedData[8] = abi.encode(extraReward4);
        serializedData[9] = abi.encode(curveLPTokenMask);
        serializedData[10] = abi.encode(stakingTokenMask);
        serializedData[11] = abi.encode(stakedTokenMask);
        serializedData[12] = abi.encode(rewardTokensMask);
        return (_gearboxAdapterType, _gearboxAdapterVersion, serializedData);
    }
}
