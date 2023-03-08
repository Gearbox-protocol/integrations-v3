// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";
import {IAdapter, AdapterType} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";
import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {IAsset} from "../../integrations/balancer/IAsset.sol";
import {
    IBalancerV2Vault,
    SwapKind,
    SingleSwap,
    FundManagement,
    BatchSwapStep,
    JoinPoolRequest,
    ExitPoolRequest
} from "../../integrations/balancer/IBalancerV2Vault.sol";
import {IBalancerV2VaultAdapter, SingleSwapAll} from "../../interfaces/balancer/IBalancerV2VaultAdapter.sol";

/// @title Balancer V2 Vault adapter
/// @notice Implements logic allowing CAs to swap through and LP in Balancer vaults
contract BalancerV2VaultAdapter is AbstractAdapter, IBalancerV2VaultAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.BALANCER_VAULT;
    uint16 public constant override _gearboxAdapterVersion = 1;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _vault Balancer vault address
    constructor(address _creditManager, address _vault) AbstractAdapter(_creditManager, _vault) {}

    /// ----- ///
    /// SWAPS ///
    /// ----- ///

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
    function swap(SingleSwap memory singleSwap, FundManagement memory, uint256 limit, uint256 deadline)
        external
        override
        creditFacadeOnly
    {
        address creditAccount = _creditAccount();

        address tokenIn = address(singleSwap.assetIn);
        address tokenOut = address(singleSwap.assetOut);

        FundManagement memory fundManagement = _getDefaultFundManagement(creditAccount);

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        _executeSwapSafeApprove(
            tokenIn,
            tokenOut,
            abi.encodeCall(IBalancerV2Vault.swap, (singleSwap, fundManagement, limit, deadline)),
            false
        ); // F: [ABV2-1]
    }

    /// @notice Swaps the entire balance of a token for another token within a single pool, disables input token
    /// @param singleSwapAll Struct containing swap parameters
    ///        * `poolId` - ID of the pool to perform a swap in
    ///        * `assetIn` - asset to send
    ///        * `assetOut` - asset to receive
    ///        * `userData` - additional generic blob used to pass extra data
    /// @param limitRateRAY The minimal resulting exchange rate of assetOut to assetIn, scaled by 1e27
    /// @param deadline The latest timestamp at which the swap would be executed
    function swapAll(SingleSwapAll memory singleSwapAll, uint256 limitRateRAY, uint256 deadline)
        external
        override
        creditFacadeOnly
    {
        address creditAccount = _creditAccount();

        address tokenIn = address(singleSwapAll.assetIn);
        address tokenOut = address(singleSwapAll.assetOut);

        uint256 balanceInBefore = IERC20(tokenIn).balanceOf(creditAccount);
        if (balanceInBefore <= 1) return;

        unchecked {
            balanceInBefore--;
        }

        FundManagement memory fundManagement = _getDefaultFundManagement(creditAccount);

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        _executeSwapSafeApprove(
            tokenIn,
            tokenOut,
            abi.encodeCall(
                IBalancerV2Vault.swap,
                (
                    SingleSwap({
                        poolId: singleSwapAll.poolId,
                        kind: SwapKind.GIVEN_IN,
                        assetIn: singleSwapAll.assetIn,
                        assetOut: singleSwapAll.assetOut,
                        amount: balanceInBefore,
                        userData: singleSwapAll.userData
                    }),
                    fundManagement,
                    (balanceInBefore * limitRateRAY) / RAY,
                    deadline
                )
            ),
            true
        ); // F: [ABV2-2]
    }

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
    ) external override creditFacadeOnly {
        address creditAccount = _creditAccount();

        FundManagement memory fundManagement = _getDefaultFundManagement(creditAccount);

        _approveAssets(assets, limits, type(uint256).max);

        int256[] memory assetDeltas = abi.decode(
            _execute(
                abi.encodeCall(IBalancerV2Vault.batchSwap, (kind, swaps, assets, fundManagement, limits, deadline))
            ),
            (int256[])
        ); // F: [ABV2-3]

        _approveAssets(assets, limits, 1);

        _enableAssets(assets, assetDeltas);
    }

    /// --------- ///
    /// JOIN POOL ///
    /// --------- ///

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
    function joinPool(bytes32 poolId, address, address, JoinPoolRequest memory request)
        external
        override
        creditFacadeOnly
    {
        address creditAccount = _creditAccount();

        (address bpt,) = IBalancerV2Vault(targetContract).getPool(poolId);

        request.fromInternalBalance = false;

        _approveAssets(request.assets, request.maxAmountsIn, type(uint256).max);
        _execute(abi.encodeCall(IBalancerV2Vault.joinPool, (poolId, creditAccount, creditAccount, request))); // F: [ABV2-4]
        _approveAssets(request.assets, request.maxAmountsIn, 1);
        _enableToken(bpt);
    }

    /// @notice Deposits single asset as liquidity into a Balancer pool
    /// @param poolId ID of the pool to deposit into
    /// @param assetIn Asset to deposit
    /// @param amountIn Amount of asset to deposit
    /// @param minAmountOut The minimal amount of BPT to receive
    function joinPoolSingleAsset(bytes32 poolId, IAsset assetIn, uint256 amountIn, uint256 minAmountOut)
        external
        override
        creditFacadeOnly
    {
        address creditAccount = _creditAccount();

        (address bpt,) = IBalancerV2Vault(targetContract).getPool(poolId);

        // calling `_executeSwap` because we need to check if BPT is registered as collateral token in the CM
        _executeSwapSafeApprove(
            address(assetIn),
            bpt,
            abi.encodeCall(
                IBalancerV2Vault.joinPool,
                (
                    poolId,
                    creditAccount,
                    creditAccount,
                    _getJoinSingleAssetRequest(poolId, assetIn, amountIn, minAmountOut)
                )
            ),
            false
        ); // F: [ABV2-5]
    }

    /// @notice Deposits the entire balance of given asset as liquidity into a Balancer pool, disables said asset
    /// @param poolId ID of the pool to deposit into
    /// @param assetIn Asset to deposit
    /// @param minRateRAY The minimal exchange rate of assetIn to BPT, scaled by 1e27
    function joinPoolSingleAssetAll(bytes32 poolId, IAsset assetIn, uint256 minRateRAY)
        external
        override
        creditFacadeOnly
    {
        address creditAccount = _creditAccount();

        uint256 balanceInBefore = IERC20(address(assetIn)).balanceOf(creditAccount);
        if (balanceInBefore <= 1) return;

        unchecked {
            balanceInBefore--;
        }

        (address bpt,) = IBalancerV2Vault(targetContract).getPool(poolId);

        // calling `_executeSwap` because we need to check if BPT is registered as collateral token in the CM
        _executeSwapSafeApprove(
            address(assetIn),
            bpt,
            abi.encodeCall(
                IBalancerV2Vault.joinPool,
                (
                    poolId,
                    creditAccount,
                    creditAccount,
                    _getJoinSingleAssetRequest(poolId, assetIn, balanceInBefore, (balanceInBefore * minRateRAY) / RAY)
                )
            ),
            true
        ); // F: [ABV2-6]
    }

    /// @dev Internal function that builds a `JoinPoolRequest` struct for one-sided deposits
    function _getJoinSingleAssetRequest(bytes32 poolId, IAsset assetIn, uint256 amountIn, uint256 minAmountOut)
        internal
        view
        returns (JoinPoolRequest memory request)
    {
        (IERC20[] memory tokens,,) = IBalancerV2Vault(targetContract).getPoolTokens(poolId);

        uint256 len = tokens.length;

        request.assets = new IAsset[](tokens.length);
        request.maxAmountsIn = new uint256[](tokens.length);

        for (uint256 i = 0; i < len;) {
            request.assets[i] = IAsset(address(tokens[i]));

            if (request.assets[i] == assetIn) {
                request.maxAmountsIn[i] = amountIn;
            }

            unchecked {
                ++i;
            }
        }

        request.userData = abi.encode(uint256(1), request.maxAmountsIn, minAmountOut);
    }

    /// --------- ///
    /// EXIT POOL ///
    /// --------- ///

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
    function exitPool(bytes32 poolId, address, address payable, ExitPoolRequest memory request)
        external
        override
        creditFacadeOnly
    {
        address creditAccount = _creditAccount();

        request.toInternalBalance = false;

        _execute(abi.encodeCall(IBalancerV2Vault.exitPool, (poolId, creditAccount, payable(creditAccount), request))); // F: [ABV2-7]
        _enableAssets(request.assets, _getBalancesFilter(creditAccount, request.assets));
    }

    /// @notice Withdraws liquidity from a Balancer pool, burning BPT and receiving a single asset
    /// @param poolId ID of the pool to withdraw from
    /// @param assetOut Asset to withdraw
    /// @param amountIn Amount of BPT to burn
    /// @param minAmountOut Minimal amount of asset to receive
    function exitPoolSingleAsset(bytes32 poolId, IAsset assetOut, uint256 amountIn, uint256 minAmountOut)
        external
        override
        creditFacadeOnly
    {
        address creditAccount = _creditAccount();

        (address bpt,) = IBalancerV2Vault(targetContract).getPool(poolId);

        // calling `_executeSwap` because we need to check if asset is registered as collateral token in the CM
        _executeSwapNoApprove(
            bpt,
            address(assetOut),
            abi.encodeCall(
                IBalancerV2Vault.exitPool,
                (
                    poolId,
                    creditAccount,
                    payable(creditAccount),
                    _getExitSingleAssetRequest(poolId, assetOut, amountIn, minAmountOut)
                )
            ),
            false
        ); // F: [ABV2-8]
    }

    /// @notice Withdraws liquidity from a Balancer pool, burning BPT and receiving a single asset, disables BPT
    /// @param poolId ID of the pool to withdraw from
    /// @param assetOut Asset to withdraw
    /// @param minRateRAY Minimal exchange rate of BPT to assetOut, scaled by 1e27
    function exitPoolSingleAssetAll(bytes32 poolId, IAsset assetOut, uint256 minRateRAY)
        external
        override
        creditFacadeOnly
    {
        address creditAccount = _creditAccount();

        (address bpt,) = IBalancerV2Vault(targetContract).getPool(poolId);

        uint256 balanceInBefore = IERC20(bpt).balanceOf(creditAccount);
        if (balanceInBefore <= 1) return;

        unchecked {
            balanceInBefore--;
        }

        // calling `_executeSwap` because we need to check if asset is registered as collateral token in the CM
        _executeSwapNoApprove(
            bpt,
            address(assetOut),
            abi.encodeCall(
                IBalancerV2Vault.exitPool,
                (
                    poolId,
                    creditAccount,
                    payable(creditAccount),
                    _getExitSingleAssetRequest(poolId, assetOut, balanceInBefore, (balanceInBefore * minRateRAY) / RAY)
                )
            ),
            true
        ); // F: [ABV2-9]
    }

    /// @dev Internal function that builds an `ExitPoolRequest` struct for one-sided withdrawals
    function _getExitSingleAssetRequest(bytes32 poolId, IAsset assetOut, uint256 amountIn, uint256 minAmountOut)
        internal
        view
        returns (ExitPoolRequest memory request)
    {
        (IERC20[] memory tokens,,) = IBalancerV2Vault(targetContract).getPoolTokens(poolId);

        uint256 len = tokens.length;

        request.assets = new IAsset[](tokens.length);
        request.minAmountsOut = new uint256[](tokens.length);
        uint256 tokenIndex = tokens.length;

        for (uint256 i = 0; i < len;) {
            request.assets[i] = IAsset(address(tokens[i]));

            if (request.assets[i] == assetOut) {
                request.minAmountsOut[i] = minAmountOut;
                tokenIndex = i;
            }

            unchecked {
                ++i;
            }
        }

        request.userData = abi.encode(uint256(0), amountIn, tokenIndex);
    }

    /// ------- ///
    /// HELPERS ///
    /// ------- ///

    /// @dev Internal function that changes approval for a batch of assets in the vault
    function _approveAssets(IAsset[] memory assets, int256[] memory filter, uint256 amount) internal {
        uint256 len = assets.length;

        for (uint256 i = 0; i < len;) {
            if (filter[i] > 1) _approveToken(address(assets[i]), amount);

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Internal function that changes approval for a batch of assets in the vault (overloading)
    function _approveAssets(IAsset[] memory assets, uint256[] memory filter, uint256 amount) internal {
        uint256 len = assets.length;

        for (uint256 i = 0; i < len;) {
            if (filter[i] > 1) _approveToken(address(assets[i]), amount);

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Internal function to enable a batch of tokens on a CA, based on balances / balance changes
    function _enableAssets(IAsset[] memory assets, int256[] memory filter) internal {
        uint256 len = assets.length;

        for (uint256 i = 0; i < len;) {
            if (filter[i] < -1) {
                _enableToken(address(assets[i]));
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Internal function that creates a filter based on CA token balances
    function _getBalancesFilter(address creditAccount, IAsset[] memory assets)
        internal
        view
        returns (int256[] memory filter)
    {
        uint256 len = assets.length;

        filter = new int256[](len);

        for (uint256 i = 0; i < len;) {
            filter[i] = -int256(IERC20(address(assets[i])).balanceOf(creditAccount));

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Returns a standard `FundManagement` struct used by the adapter
    function _getDefaultFundManagement(address creditAccount) internal pure returns (FundManagement memory) {
        return FundManagement({
            sender: creditAccount,
            fromInternalBalance: false,
            recipient: payable(creditAccount),
            toInternalBalance: false
        });
    }
}
