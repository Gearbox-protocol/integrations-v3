// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IAdapter} from "../IAdapter.sol";

import {
    IAsset,
    SingleSwap,
    FundManagement,
    SwapKind,
    BatchSwapStep,
    JoinPoolRequest,
    ExitPoolRequest
} from "../../integrations/balancer/IBalancerV2Vault.sol";

enum PoolStatus {
    NOT_ALLOWED,
    ALLOWED,
    SWAP_ONLY,
    WITHDRAWAL_ONLY
}

struct SingleSwapDiff {
    bytes32 poolId;
    uint256 leftoverAmount;
    IAsset assetIn;
    IAsset assetOut;
    bytes userData;
}

interface IBalancerV2VaultAdapterEvents {
    /// @notice Emitted when new status is set for a pool with given ID
    event SetPoolStatus(bytes32 indexed poolId, PoolStatus newStatus);
}

interface IBalancerV2VaultAdapterExceptions {
    /// @notice Thrown when attempting to swap or change liqudity in the pool that is not supported for that action
    error PoolNotSupportedException();
}

/// @title Balancer V2 Vault adapter interface
interface IBalancerV2VaultAdapter is IAdapter, IBalancerV2VaultAdapterEvents, IBalancerV2VaultAdapterExceptions {
    // ----- //
    // SWAPS //
    // ----- //

    function swap(SingleSwap memory singleSwap, FundManagement memory, uint256 limit, uint256 deadline)
        external
        returns (bool useSafePrices);

    function swapDiff(SingleSwapDiff memory singleSwapDiff, uint256 limitRateRAY, uint256 deadline)
        external
        returns (bool useSafePrices);

    function batchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        FundManagement memory,
        int256[] memory limits,
        uint256 deadline
    ) external returns (bool useSafePrices);

    // --------- //
    // JOIN POOL //
    // --------- //

    function joinPool(bytes32 poolId, address, address, JoinPoolRequest memory request)
        external
        returns (bool useSafePrices);

    function joinPoolSingleAsset(bytes32 poolId, IAsset assetIn, uint256 amountIn, uint256 minAmountOut)
        external
        returns (bool useSafePrices);

    function joinPoolSingleAssetDiff(bytes32 poolId, IAsset assetIn, uint256 leftoverAmount, uint256 minRateRAY)
        external
        returns (bool useSafePrices);

    // --------- //
    // EXIT POOL //
    // --------- //

    function exitPool(bytes32 poolId, address, address payable, ExitPoolRequest memory request)
        external
        returns (bool useSafePrices);

    function exitPoolSingleAsset(bytes32 poolId, IAsset assetOut, uint256 amountIn, uint256 minAmountOut)
        external
        returns (bool useSafePrices);

    function exitPoolSingleAssetDiff(bytes32 poolId, IAsset assetOut, uint256 leftoverAmount, uint256 minRateRAY)
        external
        returns (bool useSafePrices);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function poolStatus(bytes32 poolId) external view returns (PoolStatus);

    function setPoolStatus(bytes32 poolId, PoolStatus newStatus) external;
}
