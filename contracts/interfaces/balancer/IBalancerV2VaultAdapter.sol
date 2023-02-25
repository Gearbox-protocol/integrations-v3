// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { IAsset, SingleSwap, FundManagement, SwapKind, BatchSwapStep, JoinPoolRequest, ExitPoolRequest } from "../../integrations/balancer/IBalancerV2Vault.sol";

struct SingleSwapAll {
    bytes32 poolId;
    IAsset assetIn;
    IAsset assetOut;
    bytes userData;
}

interface IBalancerV2VaultAdapter {
    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory,
        uint256 limit,
        uint256 deadline
    ) external;

    function swapAll(
        SingleSwapAll memory singleSwapAll,
        uint256 limitRateRAY,
        uint256 deadline
    ) external;

    function batchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        FundManagement memory,
        int256[] memory limits,
        uint256 deadline
    ) external;

    function joinPool(
        bytes32 poolId,
        address,
        address,
        JoinPoolRequest memory request
    ) external;

    function joinPoolSingleAsset(
        bytes32 poolId,
        IAsset assetIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external;

    function joinPoolSingleAssetAll(
        bytes32 poolId,
        IAsset assetIn,
        uint256 minRateRAY
    ) external;

    function exitPool(
        bytes32 poolId,
        address,
        address payable,
        ExitPoolRequest memory request
    ) external;

    function exitPoolSingleAsset(
        bytes32 poolId,
        IAsset assetOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external;

    function exitPoolSingleAssetAll(
        bytes32 poolId,
        IAsset assetOut,
        uint256 minRateRAY
    ) external;
}
