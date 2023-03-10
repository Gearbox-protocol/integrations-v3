// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/adapters/IAdapter.sol";

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
    SWAP_ONLY
}

struct SingleSwapAll {
    bytes32 poolId;
    IAsset assetIn;
    IAsset assetOut;
    bytes userData;
}

interface IBalancerV2VaultAdapterExceptions {
    /// @dev Thrown when attempting to swap or change liqudity in the pool that is not supported for that action
    error PoolIDNotSupportedException();
}

/// @title Balancer V2 Vault adapter interface
/// @notice Implements logic allowing CAs to swap through and LP in Balancer vaults
interface IBalancerV2VaultAdapter is IAdapter, IBalancerV2VaultAdapterExceptions {
    /// @dev Mapping from poolId to status of the pool: whether it is not supported, fully supported or swap-only
    function poolIdStatus(bytes32 poolId) external view returns (PoolStatus);

    /// @notice Swaps a token for another token within a single pool
    /// @param singleSwap Struct containing swap parameters
    ///        * `poolId` - ID of the pool to perform a swap in
    ///        * `kind` - type of swap (GIVEN IN / GIVEN OUT)
    ///        * `assetIn` - asset to send
    ///        * `assetOut` - asset to receive
    ///        * `amount` - amount of input asset to send (for GIVEN IN) or output asset to receive (for GIVEN OUT)
    ///        * `userData` - generic blob used to pass extra data
    /// @param limit The minimal amount of `assetOut` to receive or maximal amount of `assetIn` to spend (depending on `kind`)
    /// @param deadline The latest timestamp at which the swap would be executed
    /// @dev `fundManagement` param from the original interface is ignored, as the adapter does not use internal balances and
    ///       only has one sender/recipient
    function swap(SingleSwap memory singleSwap, FundManagement memory, uint256 limit, uint256 deadline) external;

    /// @notice Swaps the entire balance of a token for another token within a single pool, disables input token
    /// @param singleSwapAll Struct containing swap parameters
    ///        * `poolId` - ID of the pool to perform a swap in
    ///        * `assetIn` - asset to send
    ///        * `assetOut` - asset to receive
    ///        * `userData` - additional generic blob used to pass extra data
    /// @param limitRateRAY The minimal resulting exchange rate of assetOut to assetIn, scaled by 1e27
    /// @param deadline The latest timestamp at which the swap would be executed
    function swapAll(SingleSwapAll memory singleSwapAll, uint256 limitRateRAY, uint256 deadline) external;

    /// @notice Performs a multi-hop swap through several Balancer pools
    /// @param kind Type of swap (GIVEN IN or GIVEN OUT)
    /// @param swaps Array of structs containing data for each individual swap:
    ///        * `poolId` - ID of the pool to perform a swap in
    ///        * `assetInIndex` - Index of the input asset in the pool (in an alphanumerically sorted array of asset addresses)
    ///        * `assetOutIndex` - Index of the output asset in the pool (in an alphanumerically sorted array of asset addresses)
    ///        * `amount` - amount of asset to send / receive. 0 signals to either spend the entire amount received from the last step,
    ///                     or to receive the exact amount needed for the next step
    ///        * `userData` - generic blob used to pass extra data
    /// @param assets Alphanumerically sorted array of assets participating in the swap
    /// @param limits Array of minimal received (negative) / maximal spent (positive) amounts, in the same order as the assets array
    /// @param deadline The latest timestamp at which the swap would be executed
    /// @dev `fundManagement` param from the original interface is ignored, as the adapter does not use internal balances and
    ///       only has one sender/recipient
    function batchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        FundManagement memory,
        int256[] memory limits,
        uint256 deadline
    ) external;

    /// @notice Deposits liquidity into a Balancer pool in exchange for BPT
    /// @param poolId ID of the pool to deposit into
    /// @param request A struct containing data for executing a deposit:
    ///        * `assets` - Array of assets in the pool
    ///        * `maxAmountsIn` - Array of maximal amounts to be spent for each asset
    ///        * `userData` - a blob encoding the type of deposit and additional parameters
    ///          (see https://dev.balancer.fi/resources/joins-and-exits/pool-joins#userdata for more info)
    ///        * `fromInternalBalance` - whether to use internal balances for assets
    ///          (ignored as the adapter does not use internal balances)
    /// @dev `sender` and `recipient` are ignored, since they are always set to the CA address
    function joinPool(bytes32 poolId, address, address, JoinPoolRequest memory request) external;

    /// @notice Deposits single asset as liquidity into a Balancer pool
    /// @param poolId ID of the pool to deposit into
    /// @param assetIn Asset to deposit
    /// @param amountIn Amount of asset to deposit
    /// @param minAmountOut The minimal amount of BPT to receive
    function joinPoolSingleAsset(bytes32 poolId, IAsset assetIn, uint256 amountIn, uint256 minAmountOut) external;

    /// @notice Deposits the entire balance of given asset as liquidity into a Balancer pool, disables said asset
    /// @param poolId ID of the pool to deposit into
    /// @param assetIn Asset to deposit
    /// @param minRateRAY The minimal exchange rate of assetIn to BPT, scaled by 1e27
    function joinPoolSingleAssetAll(bytes32 poolId, IAsset assetIn, uint256 minRateRAY) external;

    /// @notice Withdraws liquidity from a Balancer pool, burning BPT and receiving assets
    /// @param poolId ID of the pool to withdraw from
    /// @param request A struct containing data for executing a withdrawal:
    ///        * `assets` - Array of all assets in the pool
    ///        * `minAmountsOut` - The minimal amounts to receive for each asset
    ///        * `userData` - a blob encoding the type of deposit and additional parameters
    ///          (see https://dev.balancer.fi/resources/joins-and-exits/pool-exits#userdata for more info)
    ///        * `toInternalBalance` - whether to use internal balances for assets
    ///          (ignored as the adapter does not use internal balances)
    /// @dev `sender` and `recipient` are ignored, since they are always set to the CA address
    function exitPool(bytes32 poolId, address, address payable, ExitPoolRequest memory request) external;

    /// @notice Withdraws liquidity from a Balancer pool, burning BPT and receiving a single asset
    /// @param poolId ID of the pool to withdraw from
    /// @param assetOut Asset to withdraw
    /// @param amountIn Amount of BPT to burn
    /// @param minAmountOut Minimal amount of asset to receive
    function exitPoolSingleAsset(bytes32 poolId, IAsset assetOut, uint256 amountIn, uint256 minAmountOut) external;

    /// @notice Withdraws liquidity from a Balancer pool, burning BPT and receiving a single asset, disables BPT
    /// @param poolId ID of the pool to withdraw from
    /// @param assetOut Asset to withdraw
    /// @param minRateRAY Minimal exchange rate of BPT to assetOut, scaled by 1e27
    function exitPoolSingleAssetAll(bytes32 poolId, IAsset assetOut, uint256 minRateRAY) external;
}
