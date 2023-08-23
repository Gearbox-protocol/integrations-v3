// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";

import {ISwapRouter} from "../../integrations/uniswap/IUniswapV3.sol";

struct UniswapV3PoolStatus {
    address token0;
    address token1;
    uint24 fee;
    bool allowed;
}

interface IUniswapV3AdapterTypes {
    /// @notice Params for exact all input swap through a single pool
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @param fee Fee level of the pool to swap through
    /// @param deadline Maximum timestamp until which the transaction is valid
    /// @param rateMinRAY Minimum exchange rate between input and output tokens, scaled by 1e27
    /// @param sqrtPriceLimitX96 Maximum execution price, ignored if 0
    struct ExactAllInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        uint256 deadline;
        uint256 rateMinRAY;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Params for exact all input swap through multiple pools
    /// @param path Bytes-encoded swap path, see Uniswap docs for details
    /// @param deadline Maximum timestamp until which the transaction is valid
    /// @param rateMinRAY Minimum exchange rate between input and output tokens, scaled by 1e27
    struct ExactAllInputParams {
        bytes path;
        uint256 deadline;
        uint256 rateMinRAY;
    }
}

interface IUniswapV3AdapterEvents {
    /// @notice Emitted when new status is set for a pool
    event SetPoolStatus(address indexed token0, address indexed token1, uint24 indexed fee, bool allowed);
}

interface IUniswapV3AdapterExceptions {
    /// @notice Thrown when sanity checks on a swap path fail
    error InvalidPathException();
}

/// @title Uniswap V3 Router adapter interface
interface IUniswapV3Adapter is
    IAdapter,
    IUniswapV3AdapterTypes,
    IUniswapV3AdapterEvents,
    IUniswapV3AdapterExceptions
{
    function exactInputSingle(ISwapRouter.ExactInputSingleParams calldata params)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function exactAllInputSingle(ExactAllInputSingleParams calldata params)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function exactInput(ISwapRouter.ExactInputParams calldata params)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function exactAllInput(ExactAllInputParams calldata params)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function exactOutputSingle(ISwapRouter.ExactOutputSingleParams calldata params)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function exactOutput(ISwapRouter.ExactOutputParams calldata params)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function isPoolAllowed(address token0, address token1, uint24 fee) external view returns (bool);

    function setPoolStatusBatch(UniswapV3PoolStatus[] calldata pools) external;
}
