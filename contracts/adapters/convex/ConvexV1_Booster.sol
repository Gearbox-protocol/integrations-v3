// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditConfiguratorV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditConfiguratorV3.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

import {IBooster} from "../../integrations/convex/IBooster.sol";
import {IBaseRewardPool} from "../../integrations/convex/IBaseRewardPool.sol";
import {IConvexV1BoosterAdapter} from "../../interfaces/convex/IConvexV1BoosterAdapter.sol";
import {IConvexV1BaseRewardPoolAdapter} from "../../interfaces/convex/IConvexV1BaseRewardPoolAdapter.sol";

/// @title Convex V1 Booster adapter interface
/// @notice Implements logic allowing CAs to interact with Convex Booster
contract ConvexV1BoosterAdapter is AbstractAdapter, IConvexV1BoosterAdapter {
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant override contractType = "AD_CONVEX_V1_BOOSTER";
    uint256 public constant override version = 3_10;

    /// @dev Set of all pids that have corresponding phantom tokens
    EnumerableSet.UintSet internal _supportedPids;

    /// @notice Maps pool ID to Curve token being deposited
    mapping(uint256 => address) public override pidToCurveToken;

    /// @notice Maps pool ID to pool's Convex staking token
    mapping(uint256 => address) public override pidToConvexToken;

    /// @notice Maps pool ID to phantom token representing staked position
    mapping(uint256 => address) public override pidToPhantomToken;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _booster Booster contract address
    constructor(address _creditManager, address _booster)
        AbstractAdapter(_creditManager, _booster) // U:[CVX1B-1]
    {}

    /// @dev Reverts if the passed pid is not recognized by the adapter
    modifier supportedPidsOnly(uint256 pid) {
        // Checking for a supported pid is required both during deposits and withdrawals,
        // as adding pools to Convex is permissionless and not sanitizing the pid would
        // allow users to potentially run arbitrary code mid-execution
        if (!_supportedPids.contains(pid)) revert UnsupportedPidException();
        _;
    }

    // ------- //
    // DEPOSIT //
    // ------- //

    /// @notice Deposits Curve LP tokens into Booster
    /// @param _pid ID of the pool to deposit to
    /// @dev `_amount` and `_stake` parameters are ignored since calldata is passed directly to the target contract
    function deposit(uint256 _pid, uint256, bool)
        external
        override
        creditFacadeOnly // U:[CVX1B-2]
        supportedPidsOnly(_pid) // U:[CVX1B-2A]
        returns (bool)
    {
        _executeSwapSafeApprove(pidToCurveToken[_pid], msg.data); // U:[CVX1B-3]
        return false;
    }

    /// @notice Deposits the entire balance of Curve LP tokens into Booster, except the specified amount
    /// @param _pid ID of the pool to deposit to
    /// @param leftoverAmount Amount of Curve LP to keep on the account
    /// @param _stake Whether to stake Convex LP tokens in the rewards pool
    function depositDiff(uint256 _pid, uint256 leftoverAmount, bool _stake)
        external
        override
        creditFacadeOnly // U:[CVX1B-2]
        supportedPidsOnly(_pid) // U:[CVX1B-2A]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[CVX1B-4]

        address tokenIn = pidToCurveToken[_pid]; // U:[CVX1B-4]

        uint256 balance = IERC20(tokenIn).balanceOf(creditAccount); // U:[CVX1B-4]

        if (balance > leftoverAmount) {
            unchecked {
                _executeSwapSafeApprove(
                    tokenIn, abi.encodeCall(IBooster.deposit, (_pid, balance - leftoverAmount, _stake))
                ); // U:[CVX1B-4]
            }
        }

        return false;
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
        supportedPidsOnly(_pid) // U:[CVX1B-2A]
        returns (bool)
    {
        _execute(msg.data); // U:[CVX1B-5]
        return false;
    }

    /// @notice Withdraws all Curve LP tokens from Booster, except the specified amount
    /// @param _pid ID of the pool to withdraw from
    /// @param leftoverAmount Amount of Convex LP to keep on the account
    function withdrawDiff(uint256 _pid, uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[CVX1B-2]
        supportedPidsOnly(_pid) // U:[CVX1B-2A]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[CVX1B-6]

        address tokenIn = pidToConvexToken[_pid]; // U:[CVX1B-6]

        uint256 balance = IERC20(tokenIn).balanceOf(creditAccount); // U:[CVX1B-6]

        if (balance > leftoverAmount) {
            unchecked {
                _execute(abi.encodeCall(IBooster.withdraw, (_pid, balance - leftoverAmount))); // U:[CVX1B-6]
            }
        }

        return false;
    }

    // ---- //
    // DATA //
    // ---- //

    function getSupportedPids() public view returns (uint256[] memory) {
        return _supportedPids.values();
    }

    /// @notice Returns all adapter parameters serialized into a bytes array,
    ///         as well as adapter type and version, to properly deserialize
    function serialize() external view override returns (bytes memory serializedData) {
        uint256[] memory supportedPids = getSupportedPids();
        address[] memory supportedPhantomTokens = new address[](supportedPids.length);

        uint256 len = supportedPids.length;

        for (uint256 i = 0; i < len; ++i) {
            supportedPhantomTokens[i] = pidToPhantomToken[supportedPids[i]];
        }

        serializedData = abi.encode(creditManager, targetContract, supportedPids, supportedPhantomTokens);
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Updates the set of supported pids and related token mappings
    function updateSupportedPids()
        external
        override
        configuratorOnly // U:[CVX1B-7]
    {
        ICreditManagerV3 cm = ICreditManagerV3(creditManager);
        ICreditConfiguratorV3 cc = ICreditConfiguratorV3(cm.creditConfigurator());

        address[] memory allowedAdapters = cc.allowedAdapters();
        uint256 len = allowedAdapters.length;
        for (uint256 i = 0; i < len; ++i) {
            address adapter = allowedAdapters[i];
            address poolTargetContract = IAdapter(adapter).targetContract();

            if (
                IAdapter(adapter).contractType() == "AD_CONVEX_V1_BASE_REWARD_POOL"
                    && IBaseRewardPool(poolTargetContract).operator() == targetContract
            ) {
                uint256 pid = IBaseRewardPool(poolTargetContract).pid();
                address phantomToken = IConvexV1BaseRewardPoolAdapter(adapter).stakedPhantomToken();

                /// No sanity checks on pool-related tokens (Curve token, Convex token, phantom token) being collateral
                /// need to be performed, as they were already done while deploying the pool adapter itself

                pidToPhantomToken[pid] = phantomToken;
                pidToCurveToken[pid] = IConvexV1BaseRewardPoolAdapter(adapter).curveLPtoken();
                pidToConvexToken[pid] = IConvexV1BaseRewardPoolAdapter(adapter).stakingToken();

                _supportedPids.add(pid);
                emit AddSupportedPid(pid);
            }
        }
    }
}
