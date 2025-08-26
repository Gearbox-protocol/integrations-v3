// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

struct PoolKey {
    address token0;
    address token1;
    uint24 fee;
    uint24 tickSpacing;
    address hooks;
}

struct UniswapV4ExactInputSingleParams {
    PoolKey poolKey;
    bool zeroForOne;
    uint128 amountIn;
    uint128 amountOutMinimum;
    bytes hookData;
}

uint256 constant COMMAND_V4_SWAP = 0x10;
uint256 constant ACTION_SWAP_IN_SINGLE = 0x06;
uint256 constant ACTION_SETTLE_ALL = 0x0c;
uint256 constant ACTION_TAKE_ALL = 0x0f;

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs) external payable;
}
