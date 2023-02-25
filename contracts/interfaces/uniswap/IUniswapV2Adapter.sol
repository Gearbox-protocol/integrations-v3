// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { IAdapter } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

interface IUniswapV2AdapterExceptions {
    /// @dev Thrown when sanity checks on a Uniswap path fail
    error InvalidPathException();
}

interface IUniswapV2Adapter is IAdapter, IUniswapV2AdapterExceptions {
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address,
        uint256 deadline
    ) external;

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address,
        uint256 deadline
    ) external;

    function swapAllTokensForTokens(
        uint256 rateMinRAY,
        address[] calldata path,
        uint256 deadline
    ) external;
}
