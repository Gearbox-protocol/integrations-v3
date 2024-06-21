// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditConfiguratorV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditConfiguratorV3.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";
import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

import {IBooster} from "../../integrations/convex/IBooster.sol";
import {IBaseRewardPool} from "../../integrations/convex/IBaseRewardPool.sol";
import {IConvexV1BoosterAdapter} from "../../interfaces/convex/IConvexV1BoosterAdapter.sol";
import {IConvexV1BaseRewardPoolAdapter} from "../../interfaces/convex/IConvexV1BaseRewardPoolAdapter.sol";

/// @title Convex V1 Booster adapter interface
/// @notice Implements logic allowing CAs to interact with Convex Booster
contract ConvexV1BoosterAdapter is AbstractAdapter, IConvexV1BoosterAdapter {
    using EnumerableSet for EnumerableSet.UintSet;

    AdapterType public constant override _gearboxAdapterType = AdapterType.CONVEX_V1_BOOSTER;
    uint16 public constant override _gearboxAdapterVersion = 3_10;

    /// @dev Set of all pids that have corresponding phantom tokens
    EnumerableSet.UintSet internal _supportedPids;

    /// @notice Maps pool ID to phantom token representing staked position
    mapping(uint256 => address) public override pidToPhantomToken;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _booster Booster contract address
    constructor(address _creditManager, address _booster)
        AbstractAdapter(_creditManager, _booster) // U:[CVX1B-1]
    {}

    // ------- //
    // DEPOSIT //
    // ------- //

    /// @notice Deposits Curve LP tokens into Booster
    /// @param _pid ID of the pool to deposit to
    /// @param _stake Whether to stake Convex LP tokens in the rewards pool
    /// @dev `_amount` parameter is ignored since calldata is passed directly to the target contract
    function deposit(uint256 _pid, uint256, bool _stake)
        external
        override
        creditFacadeOnly // U:[CVX1B-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _deposit(_pid, _stake, msg.data, false); // U:[CVX1B-3]
    }

    /// @notice Deposits the entire balance of Curve LP tokens into Booster, except the specified amount
    /// @param _pid ID of the pool to deposit to
    /// @param leftoverAmount Amount of Curve LP to keep on the account
    /// @param _stake Whether to stake Convex LP tokens in the rewards pool
    function depositDiff(uint256 _pid, uint256 leftoverAmount, bool _stake)
        external
        override
        creditFacadeOnly // U:[CVX1B-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[CVX1B-4]

        IBooster.PoolInfo memory pool = IBooster(targetContract).poolInfo(_pid);

        address tokenIn = pool.lptoken; // U:[CVX1B-4]
        address tokenOut = _stake ? pidToPhantomToken[_pid] : pool.token; // U:[CVX1B-4]

        uint256 balance = IERC20(tokenIn).balanceOf(creditAccount); // U:[CVX1B-4]

        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
                    tokenIn,
                    tokenOut,
                    abi.encodeCall(IBooster.deposit, (_pid, balance - leftoverAmount, _stake)),
                    leftoverAmount <= 1
                ); // U:[CVX1B-4]
            }
        }
    }

    /// @dev Internal implementation of `deposit` and `depositDiff`
    ///      - Curve LP token is approved before the call
    ///      - Convex LP token (or staked phantom token, if `_stake` is true) is enabled after the call
    ///      - Curve LP token is only disabled when depositing the entire balance
    function _deposit(uint256 _pid, bool _stake, bytes memory callData, bool disableCurveLP)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        IBooster.PoolInfo memory pool = IBooster(targetContract).poolInfo(_pid);

        address tokenIn = pool.lptoken; // U:[CVX1B-3,4]
        address tokenOut = _stake ? pidToPhantomToken[_pid] : pool.token; // U:[CVX1B-3,4]

        // using `_executeSwap` because tokens are not known in advance and need to check if they are registered
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(tokenIn, tokenOut, callData, disableCurveLP); // U:[CVX1B-3,4]
    }

    // -------- //
    // WITHDRAW //
    // -------- //

    /// @notice Withdraws Curve LP tokens from Booster
    /// @param _pid ID of the pool to withdraw from
    /// @dev `_amount` parameter is ignored since calldata is passed directly to the target contract
    function withdraw(uint256 _pid, uint256)
        external
        override
        creditFacadeOnly // U:[CVX1B-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdraw(_pid, msg.data, false); // U:[CVX1B-5]
    }

    /// @notice Withdraws all Curve LP tokens from Booster, except the specified amount
    /// @param _pid ID of the pool to withdraw from
    /// @param leftoverAmount Amount of Convex LP to keep on the account
    function withdrawDiff(uint256 _pid, uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[CVX1B-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[CVX1B-6]

        IBooster.PoolInfo memory pool = IBooster(targetContract).poolInfo(_pid);

        address tokenIn = pool.token; // U:[CVX1B-6]
        address tokenOut = pool.lptoken; // U:[CVX1B-6]

        uint256 balance = IERC20(tokenIn).balanceOf(creditAccount); // U:[CVX1B-6]

        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable,) = _executeSwapNoApprove(
                    tokenIn,
                    tokenOut,
                    abi.encodeCall(IBooster.withdraw, (_pid, balance - leftoverAmount)),
                    leftoverAmount <= 1
                ); // U:[CVX1B-6]
            }
        }
    }

    /// @dev Internal implementation of `withdraw` and `withdrawDiff`
    ///      - Curve LP token is enabled after the call
    ///      - Convex LP token is only disabled when withdrawing the entire stake
    function _withdraw(uint256 _pid, bytes memory callData, bool disableConvexLP)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        IBooster.PoolInfo memory pool = IBooster(targetContract).poolInfo(_pid);

        address tokenIn = pool.token; // U:[CVX1B-5,6]
        address tokenOut = pool.lptoken; // U:[CVX1B-5,6]

        // using `_executeSwap` because tokens are not known in advance and need to check if they are registered
        (tokensToEnable, tokensToDisable,) = _executeSwapNoApprove(tokenIn, tokenOut, callData, disableConvexLP); // U:[CVX1B-5,6]
    }

    // ---- //
    // DATA //
    // ---- //

    function getSupportedPids() public view returns (uint256[] memory) {
        return _supportedPids.values();
    }

    /// @notice Returns all adapter parameters serialized into a bytes array,
    ///         as well as adapter type and version, to properly deserialize
    function serialize() external view returns (AdapterType, uint16, bytes[] memory) {
        uint256[] memory supportedPids = getSupportedPids();
        address[] memory supportedPhantomTokens = new address[](supportedPids.length);

        uint256 len = supportedPids.length;

        for (uint256 i = 0; i < len; ++i) {
            supportedPhantomTokens[i] = pidToPhantomToken[supportedPids[i]];
        }

        bytes[] memory serializedData = new bytes[](4);
        serializedData[0] = abi.encode(creditManager);
        serializedData[1] = abi.encode(targetContract);
        serializedData[2] = abi.encode(supportedPids);
        serializedData[3] = abi.encode(supportedPhantomTokens);

        return (_gearboxAdapterType, _gearboxAdapterVersion, serializedData);
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Updates the mapping of pool IDs to phantom staked token addresses
    function updateStakedPhantomTokensMap()
        external
        override
        configuratorOnly // U:[CVX1B-7]
    {
        ICreditManagerV3 cm = ICreditManagerV3(creditManager);
        ICreditConfiguratorV3 cc = ICreditConfiguratorV3(cm.creditConfigurator());

        address[] memory allowedAdapters = cc.allowedAdapters();
        uint256 len = allowedAdapters.length;
        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                address adapter = allowedAdapters[i];
                address poolTargetContract = IAdapter(adapter).targetContract();
                AdapterType aType = IAdapter(adapter)._gearboxAdapterType();

                if (
                    aType == AdapterType.CONVEX_V1_BASE_REWARD_POOL
                        && IBaseRewardPool(poolTargetContract).operator() == targetContract
                ) {
                    uint256 pid = IBaseRewardPool(poolTargetContract).pid();
                    address phantomToken = IConvexV1BaseRewardPoolAdapter(adapter).stakedPhantomToken();
                    pidToPhantomToken[pid] = phantomToken;
                    _supportedPids.add(pid);
                    emit SetPidToPhantomToken(pid, phantomToken);
                }
            }
        }
    }
}
