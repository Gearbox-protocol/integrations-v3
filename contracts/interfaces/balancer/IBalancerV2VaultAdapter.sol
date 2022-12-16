// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IBalancerV2Vault, IAsset } from "../../integrations/balancer/IBalancerV2Vault.sol";

struct SingleSwapAll {
    bytes32 poolId;
    IAsset assetIn;
    IAsset assetOut;
    bytes userData;
}

interface IBalancerV2VaultAdapter is IBalancerV2Vault {
    function swapAll(
        SingleSwapAll calldata singleSwapAll,
        uint256 limitRateRAY,
        uint256 deadline
    ) external returns (uint256 amountCalculated);

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
