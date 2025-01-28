// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {IBalancerV3Router} from "../../integrations/balancer/IBalancerV3Router.sol";
import {IBalancerV3Pool} from "../../integrations/balancer/IBalancerV3Pool.sol";
import {IBalancerV3RouterAdapter} from "../../interfaces/balancer/IBalancerV3RouterAdapter.sol";

/// @title Balancer V3 Router adapter
/// @notice Implements logic allowing CAs to perform swaps via Balancer V3
contract BalancerV3RouterAdapter is AbstractAdapter, IBalancerV3RouterAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    AdapterType public constant override _gearboxAdapterType = AdapterType.BALANCER_V3_ROUTER;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @dev Mapping from pool address to whether it can be traded through the adapter
    mapping(address => bool) internal _poolStatus;

    /// @dev Set of all pools that were ever allowed
    EnumerableSet.AddressSet internal _allowedPools;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _router Balancer V3 Router address
    constructor(address _creditManager, address _router) AbstractAdapter(_creditManager, _router) {}

    /// @notice Swaps given amount of input token for output token through a single pool
    /// @param pool Pool address
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @param exactAmountIn Exact amount of input token to swap
    /// @param minAmountOut Minimum amount of output token to receive
    /// @param deadline Deadline for the swap
    /// @dev wethIsEth and userData are ignored, since they are always set to false and empty
    function swapSingleTokenExactIn(
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 exactAmountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bool,
        bytes calldata
    ) external override creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        if (!isPoolAllowed(pool)) revert InvalidPoolException();

        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            address(tokenIn),
            address(tokenOut),
            abi.encodeCall(
                IBalancerV3Router.swapSingleTokenExactIn,
                (pool, tokenIn, tokenOut, exactAmountIn, minAmountOut, deadline, false, "")
            ),
            false
        );
    }

    /// @notice Swaps all balance of input token for output token through a single pool, except the specified amount
    /// @param pool Pool address
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @param leftoverAmount Amount of input token to keep
    /// @param rateMinRAY Minimum exchange rate [RAY]
    /// @param deadline Deadline for the swap
    function swapSingleTokenDiffIn(
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        uint256 deadline
    ) external override creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        if (!isPoolAllowed(pool)) revert InvalidPoolException();

        address creditAccount = _creditAccount();

        uint256 amount = IERC20(address(tokenIn)).balanceOf(creditAccount);
        if (amount <= leftoverAmount) return (0, 0);
        unchecked {
            amount -= leftoverAmount;
        }

        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            address(tokenIn),
            address(tokenOut),
            abi.encodeCall(
                IBalancerV3Router.swapSingleTokenExactIn,
                (pool, tokenIn, tokenOut, amount, (amount * rateMinRAY) / RAY, deadline, false, "")
            ),
            leftoverAmount <= 1
        );
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Returns whether the pool is allowed to be traded through the adapter
    function isPoolAllowed(address pool) public view override returns (bool) {
        return _poolStatus[pool];
    }

    /// @notice Returns the list of all pools that were ever allowed in this adapter
    function getAllowedPools() external view override returns (address[] memory pools) {
        return _allowedPools.values();
    }

    /// @notice Sets status for a batch of pools
    /// @param pools Array of pool addresses
    /// @param statuses Array of pool statuses
    function setPoolStatusBatch(address[] calldata pools, bool[] calldata statuses)
        external
        override
        configuratorOnly
    {
        uint256 len = pools.length;
        if (len != statuses.length) revert InvalidLengthException();
        unchecked {
            for (uint256 i; i < len; ++i) {
                _poolStatus[pools[i]] = statuses[i];
                if (statuses[i]) {
                    _allowedPools.add(pools[i]);
                } else {
                    _allowedPools.remove(pools[i]);
                }
                emit SetPoolStatus(pools[i], statuses[i]);
            }
        }
    }
}
