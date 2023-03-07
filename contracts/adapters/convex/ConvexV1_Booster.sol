// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {AbstractAdapter} from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";
import {IAdapter, AdapterType} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";
import {ACLNonReentrantTrait} from "@gearbox-protocol/core-v2/contracts/core/ACLNonReentrantTrait.sol";
import {IPoolService} from "@gearbox-protocol/core-v2/contracts/interfaces/IPoolService.sol";
import {ICreditManagerV2} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";
import {ICreditConfigurator} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditConfigurator.sol";

import {IBooster} from "../../integrations/convex/IBooster.sol";
import {IBaseRewardPool} from "../../integrations/convex/IBaseRewardPool.sol";
import {IConvexV1BoosterAdapter} from "../../interfaces/convex/IConvexV1BoosterAdapter.sol";
import {IConvexV1BaseRewardPoolAdapter} from "../../interfaces/convex/IConvexV1BaseRewardPoolAdapter.sol";

/// @title Convex V1 Booster adapter interface
/// @notice Implements logic allowing CAs to interact with Convex Booster
contract ConvexV1BoosterAdapter is AbstractAdapter, ACLNonReentrantTrait, IConvexV1BoosterAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.CONVEX_V1_BOOSTER;
    uint16 public constant override _gearboxAdapterVersion = 2;

    /// @notice Maps pool ID to phantom token representing staked position
    mapping(uint256 => address) public override pidToPhantomToken;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _booster Booster contract address
    constructor(address _creditManager, address _booster)
        ACLNonReentrantTrait(address(IPoolService(ICreditManagerV2(_creditManager).poolService()).addressProvider()))
        AbstractAdapter(_creditManager, _booster)
    {}

    /// ------- ///
    /// DEPOSIT ///
    /// ------- ///

    /// @notice Deposits Curve LP tokens into Booster
    /// @param _pid ID of the pool to deposit to
    /// @param _stake Whether to stake Convex LP tokens in the rewards pool
    /// @dev `_amount` parameter is ignored since calldata is passed directly to the target contract
    function deposit(uint256 _pid, uint256, bool _stake) external override creditFacadeOnly {
        _deposit(_pid, _stake, msg.data, false);
    }

    /// @notice Deposits the entire balance of Curve LP tokens into Booster, disables Curve LP token
    /// @param _pid ID of the pool to deposit to
    /// @param _stake Whether to stake Convex LP tokens in the rewards pool
    function depositAll(uint256 _pid, bool _stake) external override creditFacadeOnly {
        _deposit(_pid, _stake, msg.data, true);
    }

    /// @dev Internal implementation of `deposit` and `depositAll`
    ///      - Curve LP token is approved before the call
    ///      - Convex LP token (or staked phantom token, if `_stake` is true) is enabled after the call
    ///      - Curve LP token is only disabled when depositing the entire balance
    function _deposit(uint256 _pid, bool _stake, bytes memory callData, bool disableCurveLP) internal {
        IBooster.PoolInfo memory pool = IBooster(targetContract).poolInfo(_pid);

        address tokenIn = pool.lptoken; // F: [ACVX1_B-2, ACVX1_B-3]
        address tokenOut = _stake ? pidToPhantomToken[_pid] : pool.token; // F: [ACVX1_B-2, ACVX1_B-3]

        // using `_executeSwap` because tokens are not known in advance and need to check if they are registered
        _executeSwapSafeApprove(tokenIn, tokenOut, callData, disableCurveLP);
    }

    /// -------- ///
    /// WITHDRAW ///
    /// -------- ///

    /// @notice Withdraws Curve LP tokens from Booster
    /// @param _pid ID of the pool to withdraw from
    /// @dev `_amount` parameter is ignored since calldata is passed directly to the target contract
    function withdraw(uint256 _pid, uint256) external override creditFacadeOnly {
        _withdraw(_pid, msg.data, false);
    }

    /// @notice Withdraws all Curve LP tokens from Booster, disables Convex LP token
    /// @param _pid ID of the pool to withdraw from
    /// @dev `_amount` parameter is ignored since calldata is passed directly to the target contract
    function withdrawAll(uint256 _pid) external override creditFacadeOnly {
        _withdraw(_pid, msg.data, true);
    }

    /// @dev Internal implementation of `withdraw` and `withdrawAll`
    ///      - Curve LP token is enabled after the call
    ///      - Convex LP token is only disabled when withdrawing the entire stake
    function _withdraw(uint256 _pid, bytes memory callData, bool disableConvexLP) internal {
        IBooster.PoolInfo memory pool = IBooster(targetContract).poolInfo(_pid);

        address tokenIn = pool.token; // F: [ACVX1_B-4, ACVX1_B-5]
        address tokenOut = pool.lptoken; // F: [ACVX1_B-4, ACVX1_B-5]

        // using `_executeSwap` because tokens are not known in advance and need to check if they are registered
        _executeSwapNoApprove(tokenIn, tokenOut, callData, disableConvexLP);
    }

    /// ------ ///
    /// CONFIG ///
    /// ------ ///

    /// @notice Updates the mapping of pool IDs to phantom staked token addresses
    function updateStakedPhantomTokensMap()
        external
        configuratorOnly // F: [ACVX1_B-1]
    {
        ICreditConfigurator cc = ICreditConfigurator(creditManager.creditConfigurator());

        address[] memory allowedContracts = cc.allowedContracts();
        uint256 len = allowedContracts.length;

        for (uint256 i = 0; i < len;) {
            address allowedContract = allowedContracts[i];

            address adapter = creditManager.contractToAdapter(allowedContract);
            AdapterType aType = IAdapter(adapter)._gearboxAdapterType();

            if (aType == AdapterType.CONVEX_V1_BASE_REWARD_POOL) {
                uint256 pid = IBaseRewardPool(allowedContract).pid();
                pidToPhantomToken[pid] = IConvexV1BaseRewardPoolAdapter(adapter).stakedPhantomToken();
            }

            unchecked {
                ++i;
            }
        }
    }
}
