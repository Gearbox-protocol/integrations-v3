// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

import {IUniswapV4Gateway, PoolKey} from "./IUniswapV4Gateway.sol";

struct UniswapV4PoolStatus {
    PoolKey poolKey;
    bool allowed;
}

/// @title Uniswap V4 Router adapter interface
interface IUniswapV4Adapter is IAdapter {
    event SetPoolKeyStatus(
        address indexed token0, address indexed token1, uint24 fee, uint24 tickSpacing, address hooks, bool allowed
    );

    error InvalidPoolKeyException();

    function swapExactInputSingle(
        PoolKey calldata poolKey,
        bool zeroForOne,
        uint128 amountIn,
        uint128 amountOutMinimum,
        bytes calldata hooks
    ) external returns (bool);

    function swapExactInputSingleDiff(
        PoolKey calldata poolKey,
        bool zeroForOne,
        uint128 leftoverAmount,
        uint128 rateMinRAY
    ) external returns (bool);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function supportedPoolKeys() external view returns (PoolKey[] memory poolKeys);

    function isPoolKeyAllowed(PoolKey calldata poolKey) external view returns (bool);

    function setPoolKeyStatusBatch(UniswapV4PoolStatus[] calldata poolKeys) external;
}
