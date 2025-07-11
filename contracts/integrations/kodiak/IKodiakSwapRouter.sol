// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}

interface IKodiakSwapRouter {
    function exactInputSingle(ExactInputSingleParams memory params) external returns (uint256 amountOut);
}
