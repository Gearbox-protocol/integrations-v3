// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {Route} from "../../integrations/velodrome/IVelodromeV2Router.sol";

struct VelodromeV2Pool {
    address token0;
    address token1;
    bool stable;
    address factory;
}

struct VelodromeV2PoolStatus {
    address token0;
    address token1;
    bool stable;
    address factory;
    bool allowed;
}

interface IVelodromeV2AdapterEvents {
    /// @notice Emited when new status is set for a pair
    event SetPoolStatus(address indexed token0, address indexed token1, bool stable, address factory, bool allowed);
}

interface IVelodromeV2AdapterExceptions {
    /// @notice Thrown when sanity checks on a swap path fail
    error InvalidPathException();
}

/// @title Velodrome V2 Router adapter interface
interface IVelodromeV2RouterAdapter is IAdapter, IVelodromeV2AdapterEvents, IVelodromeV2AdapterExceptions {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address,
        uint256 deadline
    ) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function swapDiffTokensForTokens(
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        Route[] calldata routes,
        uint256 deadline
    ) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function isPoolAllowed(address token0, address token1, bool stable, address factory) external view returns (bool);

    function setPoolStatusBatch(VelodromeV2PoolStatus[] calldata pools) external;
}
