// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IAdapter} from "../IAdapter.sol";
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

/// @title Velodrome V2 Router adapter interface
interface IVelodromeV2RouterAdapter is IAdapter {
    /// @notice Emited when new status is set for a pair
    event SetPoolStatus(address indexed token0, address indexed token1, bool stable, address factory, bool allowed);

    /// @notice Thrown when sanity checks on a swap path fail
    error InvalidPathException();

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address,
        uint256 deadline
    ) external returns (bool useSafePrices);

    function swapDiffTokensForTokens(
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        Route[] calldata routes,
        uint256 deadline
    ) external returns (bool useSafePrices);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function isPoolAllowed(address token0, address token1, bool stable, address factory) external view returns (bool);

    function setPoolStatusBatch(VelodromeV2PoolStatus[] calldata pools) external;
}
