// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

struct UniswapV2Pair {
    address token0;
    address token1;
}

struct UniswapV2PairStatus {
    address token0;
    address token1;
    bool allowed;
}

interface IUniswapV2AdapterEvents {
    /// @notice Emited when new status is set for a pair
    event SetPairStatus(address indexed token0, address indexed token1, bool allowed);
}

interface IUniswapV2AdapterExceptions {
    /// @notice Thrown when sanity checks on a swap path fail
    error InvalidPathException();
}

/// @title Uniswap V2 Router adapter interface
interface IUniswapV2Adapter is IAdapter, IUniswapV2AdapterEvents, IUniswapV2AdapterExceptions {
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address,
        uint256 deadline
    ) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address,
        uint256 deadline
    ) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function swapDiffTokensForTokens(
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        address[] calldata path,
        uint256 deadline
    ) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function isPairAllowed(address token0, address token1) external view returns (bool);

    function setPairStatusBatch(UniswapV2PairStatus[] calldata pairs) external;
}
