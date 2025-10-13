// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBalancerV3RouterAdapterEvents {
    /// @notice Emitted when pool status is changed
    event SetPoolStatus(address indexed pool, bool allowed);
}

interface IBalancerV3RouterAdapterExceptions {
    /// @notice Thrown when pool and status array lengths do not match
    error InvalidLengthException();

    /// @notice Thrown when trying to swap through a non-allowed pool
    error InvalidPoolException();
}

/// @title Balancer V3 Router adapter interface
interface IBalancerV3RouterAdapter is IAdapter, IBalancerV3RouterAdapterEvents, IBalancerV3RouterAdapterExceptions {
    function swapSingleTokenExactIn(
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 exactAmountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    ) external returns (bool);

    function swapSingleTokenDiffIn(
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        uint256 deadline
    ) external returns (bool);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Returns whether the pool is allowed to be traded through the adapter
    function isPoolAllowed(address pool) external view returns (bool);

    /// @notice Returns the list of all pools that were ever allowed in this adapter
    function getAllowedPools() external view returns (address[] memory pools);

    /// @notice Sets status for a batch of pools
    function setPoolStatusBatch(address[] calldata pools, bool[] calldata statuses) external;
}
