// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {AbstractAdapter} from "../AbstractAdapter.sol";
import {BitMask} from "@gearbox-protocol/core-v3/contracts/libraries/BitMask.sol";

import {IBooster} from "../../integrations/convex/IBooster.sol";
import {IBaseRewardPool} from "../../integrations/convex/IBaseRewardPool.sol";
import {IRewards, IExtraRewardWrapper, IAuraL2Coordinator} from "../../integrations/convex/Interfaces.sol";
import {IConvexV1BaseRewardPoolAdapter} from "../../interfaces/convex/IConvexV1BaseRewardPoolAdapter.sol";

/// @title Convex V1 BaseRewardPool adapter interface
/// @notice Implements logic for interacting with Convex reward pool
contract ConvexV1BaseRewardPoolAdapter is AbstractAdapter, IConvexV1BaseRewardPoolAdapter {
    using BitMask for uint256;

    bytes32 public constant override contractType = "AD_CONVEX_V1_BASE_REWARD_POOL";
    uint256 public constant override version = 3_10;

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

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _baseRewardPool BaseRewardPool address
    /// @param _stakedPhantomToken Reward pool stake token address
    constructor(address _creditManager, address _baseRewardPool, address _stakedPhantomToken)
        AbstractAdapter(_creditManager, _baseRewardPool) // U:[CVX1R-1]
    {
        stakingToken = address(IBaseRewardPool(_baseRewardPool).stakingToken()); // U:[CVX1R-1]
        _getMaskOrRevert(stakingToken); // U:[CVX1R-1]

        stakedPhantomToken = _stakedPhantomToken; // U:[CVX1R-1]
        _getMaskOrRevert(stakedPhantomToken); // U:[CVX1R-1]

        address booster = IBaseRewardPool(_baseRewardPool).operator();
        IBooster.PoolInfo memory poolInfo = IBooster(booster).poolInfo(IBaseRewardPool(_baseRewardPool).pid());
        curveLPtoken = poolInfo.lptoken; // U:[CVX1R-1]
        _getMaskOrRevert(curveLPtoken); // U:[CVX1R-1]

        address rewardToken = address(IBaseRewardPool(_baseRewardPool).rewardToken());
        _getMaskOrRevert(rewardToken); // U:[CVX1R-1]
        _checkSecondaryRewardMask(booster); // U:[CVX1R-1]

        address _extraReward1;
        address _extraReward2;
        address _extraReward3;
        address _extraReward4;
        uint256 extraRewardLength = IBaseRewardPool(_baseRewardPool).extraRewardsLength();

        if (extraRewardLength >= 1) {
            _extraReward1 = _getExtraReward(0);

            if (extraRewardLength >= 2) {
                _extraReward2 = _getExtraReward(1);

                if (extraRewardLength >= 3) {
                    _extraReward3 = _getExtraReward(2);

                    if (extraRewardLength >= 4) {
                        _extraReward4 = _getExtraReward(3);
                    }
                }
            }
        }

        extraReward1 = _extraReward1; // U:[CVX1R-2]
        extraReward2 = _extraReward2; // U:[CVX1R-2]
        extraReward3 = _extraReward3; // U:[CVX1R-2]
        extraReward4 = _extraReward4; // U:[CVX1R-2]
    }

    /// @dev Returns `i`-th extra reward token and checks that it is a valid collateral in the Credit Manager
    function _getExtraReward(uint256 i) internal view returns (address extraReward) {
        extraReward = IRewards(IBaseRewardPool(targetContract).extraRewards(i)).rewardToken();

        // `extraReward` might be a wrapper around the reward token, and there seems to be no reliable way to check it
        // programatically, so we assume that it's a wrapper if it's not recognized as collateral in the credit manager
        try ICreditManagerV3(creditManager).getTokenMaskOrRevert(extraReward) returns (uint256) {}
        catch {
            try IExtraRewardWrapper(extraReward).token() returns (address baseToken) {
                extraReward = baseToken;
            } catch {
                extraReward = IExtraRewardWrapper(extraReward).baseToken();
            }
            _getMaskOrRevert(extraReward);
        }
    }

    /// @dev Checks that the secondary token is a valid collateral.
    /// @dev Aura on L2 networks can have a different contract instead of the secondary reward token
    ///      in IBooster.minter(). If the minter is not recognized as collateral in CM, we assume that
    ///      it is not the secondary reward and handle the situation
    function _checkSecondaryRewardMask(address booster) internal view {
        address reward = IBooster(booster).minter();

        try ICreditManagerV3(creditManager).getTokenMaskOrRevert(reward) returns (uint256) {}
        catch {
            reward = IAuraL2Coordinator(reward).auraOFT();
            _getMaskOrRevert(reward);
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
        returns (bool)
    {
        _executeSwapSafeApprove(stakingToken, msg.data); // U:[CVX1R-4]
        return false;
    }

    /// @notice Stakes the entire balance of Convex LP token in the reward pool, except the specified amount
    /// @param leftoverAmount Amount of Convex LP to keep on the account
    function stakeDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[CVX1R-3]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[CVX1R-5]

        uint256 balance = IERC20(stakingToken).balanceOf(creditAccount); // U:[CVX1R-5]

        if (balance > leftoverAmount) {
            unchecked {
                _executeSwapSafeApprove(stakingToken, abi.encodeCall(IBaseRewardPool.stake, (balance - leftoverAmount))); // U:[CVX1R-5]
            }
        }
        return false;
    }

    // ----- //
    // CLAIM //
    // ----- //

    /// @notice Claims rewards on the current position, enables reward tokens
    function getReward()
        external
        override
        creditFacadeOnly // U:[CVX1R-3]
        returns (bool)
    {
        _execute(msg.data); // U:[CVX1R-6]
        return false;
    }

    // -------- //
    // WITHDRAW //
    // -------- //

    /// @notice Withdraws Convex LP token from the reward pool
    /// @dev `amount` and `claim` parameters are ignored since calldata is passed directly to the target contract
    function withdraw(uint256, bool)
        external
        override
        creditFacadeOnly // U:[CVX1R-3]
        returns (bool)
    {
        _execute(msg.data); // U:[CVX1R-7]
        return false;
    }

    /// @notice Withdraws the entire balance of Convex LP token from the reward pool, except the specified amount
    /// @param leftoverAmount Amount of staked Convex LP to keep on the account
    /// @param claim Whether to claim staking rewards
    function withdrawDiff(uint256 leftoverAmount, bool claim)
        external
        override
        creditFacadeOnly // U:[CVX1R-3]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[CVX1R-6]

        uint256 balance = IERC20(stakedPhantomToken).balanceOf(creditAccount); // U:[CVX1R-6]

        if (balance > leftoverAmount) {
            unchecked {
                _execute(abi.encodeCall(IBaseRewardPool.withdraw, (balance - leftoverAmount, claim))); // U:[CVX1R-6]
            }
        }

        return false;
    }

    /// @notice Withdraws phantom token for its underlying
    /// @dev `token` parameter is ignored as adapter only handles one token
    function withdrawPhantomToken(address, uint256 amount)
        external
        override
        creditFacadeOnly // U:[CVX1R-3]
        returns (bool)
    {
        _execute(abi.encodeCall(IBaseRewardPool.withdraw, (amount, false)));
        return false;
    }

    // ------ //
    // UNWRAP //
    // ------ //

    /// @notice Withdraws Convex LP token from the reward pool and unwraps it into Curve LP token
    /// @dev `amount` and `claim` parameters are ignored since calldata is passed directly to the target contract
    function withdrawAndUnwrap(uint256, bool)
        external
        override
        creditFacadeOnly // U:[CVX1R-3]
        returns (bool)
    {
        _execute(msg.data); // U:[CVX1R-9]
        return false;
    }

    /// @notice Withdraws the entire balance of Convex LP token from the reward pool, except the specified amount
    ///         disables staked token
    /// @param leftoverAmount Amount of staked token to keep on the account
    /// @param claim Whether to claim staking rewards
    function withdrawDiffAndUnwrap(uint256 leftoverAmount, bool claim)
        external
        override
        creditFacadeOnly // U:[CVX1R-3]
        returns (bool enableSafePrices)
    {
        address creditAccount = _creditAccount(); // U:[CVX1R-10]

        uint256 balance = IERC20(stakedPhantomToken).balanceOf(creditAccount); // U:[CVX1R-10]

        if (balance > leftoverAmount) {
            unchecked {
                _execute(abi.encodeCall(IBaseRewardPool.withdrawAndUnwrap, (balance - leftoverAmount, claim))); // U:[CVX1R-10]
            }
        }

        return false;
    }

    /// @notice Returns all adapter parameters serialized into a bytes array,
    ///         as well as adapter type and version, to properly deserialize
    function serialize() external view override returns (bytes memory serializedData) {
        serializedData = abi.encode(
            creditManager,
            targetContract,
            curveLPtoken,
            stakingToken,
            stakedPhantomToken,
            [extraReward1, extraReward2, extraReward3, extraReward4]
        );
    }
}
