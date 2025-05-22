// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

struct Implementations {
    address shift;
    address admin;
    address colOperations;
    address debtOperations;
    address perfectOperationsAndOracle;
}

struct ConstantViews {
    uint256 dexId;
    address liquidity;
    address factory;
    Implementations implementations;
    address deployerContract;
    address token0;
    address token1;
    bytes32 supplyToken0Slot;
    bytes32 borrowToken0Slot;
    bytes32 supplyToken1Slot;
    bytes32 borrowToken1Slot;
    bytes32 exchangePriceToken0Slot;
    bytes32 exchangePriceToken1Slot;
    uint256 oracleMapping;
}

interface IFluidDex {
    function swapIn(bool swap0to1, uint256 amountIn, uint256 amountOutMin, address to)
        external
        returns (uint256 amountOut);

    function constantsView() external view returns (ConstantViews memory);
}
