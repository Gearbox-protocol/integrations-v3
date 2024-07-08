// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023
pragma solidity ^0.8.23;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";

import {
    IAsset,
    SingleSwap,
    SingleSwapDiff,
    FundManagement,
    SwapKind,
    BatchSwapStep,
    JoinPoolRequest,
    ExitPoolRequest,
    IBalancerV2VaultAdapter
} from "../../../interfaces/balancer/IBalancerV2VaultAdapter.sol";

interface BalancerV2_Multicaller {}

library BalancerV2_Calls {
    function swap(
        BalancerV2_Multicaller c,
        SingleSwap memory singleSwap,
        FundManagement memory,
        uint256 limit,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        FundManagement memory fm;
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IBalancerV2VaultAdapter.swap, (singleSwap, fm, limit, deadline))
        });
    }

    function swapDiff(
        BalancerV2_Multicaller c,
        SingleSwapDiff memory singleSwapDiff,
        uint256 limitRateRAY,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IBalancerV2VaultAdapter.swapDiff, (singleSwapDiff, limitRateRAY, deadline))
        });
    }

    function batchSwap(
        BalancerV2_Multicaller c,
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        FundManagement memory,
        int256[] memory limits,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        FundManagement memory fm;
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IBalancerV2VaultAdapter.batchSwap, (kind, swaps, assets, fm, limits, deadline))
        });
    }

    function joinPool(BalancerV2_Multicaller c, bytes32 poolId, address, address, JoinPoolRequest memory request)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IBalancerV2VaultAdapter.joinPool, (poolId, address(0), address(0), request))
        });
    }

    function joinPoolSingleAsset(
        BalancerV2_Multicaller c,
        bytes32 poolId,
        IAsset assetIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IBalancerV2VaultAdapter.joinPoolSingleAsset, (poolId, assetIn, amountIn, minAmountOut))
        });
    }

    function joinPoolSingleAssetDiff(
        BalancerV2_Multicaller c,
        bytes32 poolId,
        IAsset assetIn,
        uint256 leftoverAmount,
        uint256 minRateRAY
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(
                IBalancerV2VaultAdapter.joinPoolSingleAssetDiff, (poolId, assetIn, leftoverAmount, minRateRAY)
                )
        });
    }

    function exitPool(
        BalancerV2_Multicaller c,
        bytes32 poolId,
        address,
        address payable,
        ExitPoolRequest memory request
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IBalancerV2VaultAdapter.exitPool, (poolId, address(0), payable(0), request))
        });
    }

    function exitPoolSingleAsset(
        BalancerV2_Multicaller c,
        bytes32 poolId,
        IAsset assetOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(
                IBalancerV2VaultAdapter.exitPoolSingleAsset, (poolId, assetOut, amountIn, minAmountOut)
                )
        });
    }

    function exitPoolSingleAssetDiff(
        BalancerV2_Multicaller c,
        bytes32 poolId,
        IAsset assetOut,
        uint256 leftoverAmount,
        uint256 minRateRAY
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(
                IBalancerV2VaultAdapter.exitPoolSingleAssetDiff, (poolId, assetOut, leftoverAmount, minRateRAY)
                )
        });
    }
}
