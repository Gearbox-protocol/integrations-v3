// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { AbstractAdapter } from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";
import { IAsset } from "../../integrations/balancer/IAsset.sol";
import { IBalancerV2Vault, SwapKind, SingleSwap, FundManagement, BatchSwapStep, JoinPoolRequest, ExitPoolRequest, PoolSpecialization } from "../../integrations/balancer/IBalancerV2Vault.sol";
import { IBalancerV2VaultAdapter, SingleSwapAll } from "../../interfaces/balancer/IBalancerV2VaultAdapter.sol";
import { IAdapter, AdapterType } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

import { RAY } from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

// EXCEPTIONS
import { NotImplementedException } from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

/// @title BalancerVault adapter
contract BalancerV2VaultAdapter is
    AbstractAdapter,
    IBalancerV2VaultAdapter,
    ReentrancyGuard
{
    AdapterType public constant _gearboxAdapterType = AdapterType.ABSTRACT;
    uint16 public constant _gearboxAdapterVersion = 1;

    /// @dev Constructor
    /// @param _creditManager Address Credit manager
    /// @param _vault Address of IBalancerV2Vault
    constructor(
        address _creditManager,
        address _vault
    ) AbstractAdapter(_creditManager, _vault) {}

    /// @dev Sends an order to swap a token for another token within a single pool
    /// @param singleSwap Struct containing swap parameters
    ///                   * poolId - ID of the pool to perform a swap in
    ///                   * kind - type of swap (GIVEN IN / GIVEN OUT)
    ///                   * assetIn - asset to send
    ///                   * assetOut - asset to receive
    ///                   * amount - amount of input asset to send (for GIVEN IN) or output asset to receive (for GIVEN OUT)
    ///                   * userData - generic blob used to pass extra data
    /// @param limit The minimal amount of assetOut to receive or maximal amount of assetIn to spend (depending on SwapKind)
    /// @param deadline The latest date at which the swap would be executed
    /// @return amountCalculated The amount of assetIn spent / assetOut received
    /// @notice `fundManagement` param from the original interface is ignored, as the adapter does not use internal balances and
    ///         only has one sender/recipient
    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory,
        uint256 limit,
        uint256 deadline
    ) external returns (uint256 amountCalculated) {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );

        address tokenIn = address(singleSwap.assetIn);
        address tokenOut = address(singleSwap.assetOut);

        FundManagement memory fundManagement = _getDefaultFundManagement(
            creditAccount
        );

        amountCalculated = abi.decode(
            _safeExecuteFastCheck(
                creditAccount,
                tokenIn,
                tokenOut,
                abi.encodeWithSelector(
                    IBalancerV2Vault.swap.selector,
                    singleSwap,
                    fundManagement,
                    limit,
                    deadline
                ),
                true,
                false
            ),
            (uint256)
        );
    }

    /// @dev Sends an order to swap the entire balance of a token for another token within a single pool
    /// @param singleSwapAll Struct containing swap parameters
    ///                   * poolId - ID of the pool to perform a swap in
    ///                   * assetIn - asset to send
    ///                   * assetOut - asset to receive
    ///                   * userData - additional generic blob used to pass extra data
    /// @param limitRateRAY The minimal resulting exchange rate of assetOut to assetIn
    /// @param deadline The latest date at which the swap would be executed
    /// @return amountCalculated The amount of assetOut received
    function swapAll(
        SingleSwapAll memory singleSwapAll,
        uint256 limitRateRAY,
        uint256 deadline
    ) external returns (uint256 amountCalculated) {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );

        address tokenIn = address(singleSwapAll.assetIn);
        address tokenOut = address(singleSwapAll.assetOut);

        uint256 balanceInBefore = IERC20(tokenIn).balanceOf(creditAccount);

        if (balanceInBefore > 1) {
            unchecked {
                balanceInBefore--;
            }

            FundManagement memory fundManagement = _getDefaultFundManagement(
                creditAccount
            );

            amountCalculated = abi.decode(
                _safeExecuteFastCheck(
                    creditAccount,
                    tokenIn,
                    tokenOut,
                    abi.encodeWithSelector(
                        IBalancerV2Vault.swap.selector,
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
                    ),
                    true,
                    true
                ),
                (uint256)
            );
        }
    }

    /// @dev Sends an order to do a multi-hop swap through several Balancer pools
    /// @param kind Type of swap (GIVEN IN or GIVEN OUT)
    /// @param swaps Array of structs containing data on each individual swap:
    ///              * poolId - ID of the pool to perform a swap in
    ///              * assetInIndex - Index of the input asset in the pool (in an alphanumerically sorted array of asset addresses)
    ///              * assetOutIndex - Index of the output asset in the pool (in an alphanumerically sorted array of asset addresses)
    ///              * amount - amount of asset to send / receive. 0 signals to either spend the entire amount received from the last step,
    ///                         or to receive the exact amount needed for the next step
    ///              * userData - generic blob used to pass extra data
    /// @param assets Alphanumerically sorted array of assets participating in the swap
    /// @param limits Array of minimal received (negative) / maximal spent (positive) amounts, in the same order as the assets array
    /// @param deadline The latest date at which the swap would be executed
    /// @return assetDeltas Changes in the vault balances as a result of the swap, in the same order as `assets`
    function batchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        FundManagement memory,
        int256[] memory limits,
        uint256 deadline
    ) external returns (int256[] memory assetDeltas) {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );

        FundManagement memory fundManagement = _getDefaultFundManagement(
            creditAccount
        );

        _approveAssets(assets, limits, type(uint256).max);

        assetDeltas = abi.decode(
            _execute(
                abi.encodeWithSelector(
                    IBalancerV2Vault.batchSwap.selector,
                    kind,
                    swaps,
                    assets,
                    fundManagement,
                    limits,
                    deadline
                )
            ),
            (int256[])
        );

        _approveAssets(assets, limits, 1);

        _enableAssets(creditAccount, assets, assetDeltas);

        _fullCheck(creditAccount);
    }

    /// @dev Simulates a Balancer batch swap to retrieve resulting assetDeltas
    /// @param kind Type of swap (GIVEN IN or GIVEN OUT)
    /// @param swaps Array of structs containing data on each individual swap:
    ///              * poolId - ID of the pool to perform a swap in
    ///              * assetInIndex - Index of the input asset in the pool (in an alphanumerically sorted array of asset addresses)
    ///              * assetOutIndex - Index of the output asset in the pool (in an alphanumerically sorted array of asset addresses)
    ///              * amount - amount of asset to send / receive. 0 signals to either spend the entire amount received from the last step,
    ///                         or to receive the exact amount needed for the next step
    ///              * userData - generic blob used to pass extra data
    /// @param assets Alphanumerically sorted array of assets participating in the swap
    /// @return assetDeltas Changes in the vault balances as a result of the swap, in the same order as `assets`
    /// @notice Does not do a health check, since queryBatchSwap cannot change Vault / CA state
    function queryBatchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        FundManagement memory
    ) external returns (int256[] memory assetDeltas) {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );

        FundManagement memory fundManagement = _getDefaultFundManagement(
            creditAccount
        );

        return
            IBalancerV2Vault(targetContract).queryBatchSwap(
                kind,
                swaps,
                assets,
                fundManagement
            );
    }

    /// @dev Sends an order to deposit liquidity into a Balancer pool and receive BPT
    /// @param poolId ID of the pool to deposit into
    /// @param request A struct containing data for executing a deposit:
    ///                * assets - Array of assets in the pool
    ///                * maxAmountsIn - Array of maximal amounts to be spent for each asset
    ///                * userData - a blob encoding the type of deposit and additional parameters
    ///                  (see https://dev.balancer.fi/resources/joins-and-exits/pool-joins#userdata for more info)
    ///                * fromInternalBalance - whether to use internal balances for assets (ignored as the adapter does not use internal balances)
    /// @notice Sender and recipient are ignored, since they are always set to the creditAccount address
    function joinPool(
        bytes32 poolId,
        address,
        address,
        JoinPoolRequest memory request
    ) external {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );

        (address bpt, ) = IBalancerV2Vault(targetContract).getPool(poolId);

        request.fromInternalBalance = false;

        _approveAssets(request.assets, request.maxAmountsIn, type(uint256).max);
        _enableToken(creditAccount, bpt);

        _execute(
            abi.encodeWithSelector(
                IBalancerV2Vault.joinPool.selector,
                poolId,
                creditAccount,
                creditAccount,
                request
            )
        );

        _approveAssets(request.assets, request.maxAmountsIn, 1);

        _fullCheck(creditAccount);
    }

    /// @dev Sends an order to deposit liquidity into a Balancer pool in one asset
    /// @param poolId ID of the pool to deposit into
    /// @param assetIn Asset to deposit
    /// @param amountIn Amount of asset to deposit
    /// @param minAmountOut The minimal amount of BPT to receive
    function joinPoolSingleAsset(
        bytes32 poolId,
        IAsset assetIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );

        (address bpt, ) = IBalancerV2Vault(targetContract).getPool(poolId);

        _safeExecuteFastCheck(
            creditAccount,
            address(assetIn),
            bpt,
            abi.encodeWithSelector(
                IBalancerV2Vault.joinPool.selector,
                poolId,
                creditAccount,
                creditAccount,
                _getJoinSingleAssetRequest(
                    poolId,
                    assetIn,
                    amountIn,
                    minAmountOut
                )
            ),
            true,
            false
        );
    }

    /// @dev Sends an order to deposit liquidity into a Balancer pool in one asset, using the entire balance
    /// @param poolId ID of the pool to deposit into
    /// @param assetIn Asset to deposit
    /// @param minRateRAY The minimal exchange rate of assetIn to BPT
    function joinPoolSingleAssetAll(
        bytes32 poolId,
        IAsset assetIn,
        uint256 minRateRAY
    ) external {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );

        uint256 balanceInBefore = IERC20(address(assetIn)).balanceOf(
            creditAccount
        );

        if (balanceInBefore > 1) {
            unchecked {
                balanceInBefore--;
            }

            (address bpt, ) = IBalancerV2Vault(targetContract).getPool(poolId);

            _safeExecuteFastCheck(
                creditAccount,
                address(assetIn),
                bpt,
                abi.encodeWithSignature(
                    "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
                    poolId,
                    creditAccount,
                    creditAccount,
                    _getJoinSingleAssetRequest(
                        poolId,
                        assetIn,
                        balanceInBefore,
                        (balanceInBefore * minRateRAY) / RAY
                    )
                ),
                true,
                true
            );
        }
    }

    /// @dev Internal function that builds a JoinPoolRequest struct for one-sided deposits
    function _getJoinSingleAssetRequest(
        bytes32 poolId,
        IAsset assetIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal view returns (JoinPoolRequest memory request) {
        (IERC20[] memory tokens, , ) = IBalancerV2Vault(targetContract)
            .getPoolTokens(poolId);

        uint256 len = tokens.length;

        request.assets = new IAsset[](tokens.length);
        request.maxAmountsIn = new uint256[](tokens.length);

        for (uint256 i = 0; i < len; ) {
            request.assets[i] = IAsset(address(tokens[i]));

            if (request.assets[i] == assetIn) {
                request.maxAmountsIn[i] = amountIn;
            }

            unchecked {
                ++i;
            }
        }

        request.userData = abi.encode(
            uint256(1),
            request.maxAmountsIn,
            minAmountOut
        );
    }

    /// @dev Sends an order to withdraw liquidity from a Balancer pool, burning BPT and receiving assets
    /// @param poolId ID of the pool to withdraw from
    /// @param request A struct containing data for executing a withdrawal:
    ///                * assets - Array of all assets in the pool
    ///                * minAmountsOut - The minimal amounts to receive for each asset
    ///                * userData - a blob encoding the type of deposit and additional parameters
    ///                (see https://dev.balancer.fi/resources/joins-and-exits/pool-exits#userdata for more info)
    ///                * toInternalBalance - whether to use internal balances for assets (ignored as the adapter does not use internal balances)
    /// @notice Sender and recipient are ignored, since they are always set to the creditAccount address
    function exitPool(
        bytes32 poolId,
        address,
        address payable,
        ExitPoolRequest memory request
    ) external {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );

        request.toInternalBalance = false;

        _execute(
            abi.encodeWithSelector(
                IBalancerV2Vault.exitPool.selector,
                poolId,
                creditAccount,
                creditAccount,
                request
            )
        );

        _enableAssets(
            creditAccount,
            request.assets,
            _getBalancesFilter(creditAccount, request.assets)
        );

        _fullCheck(creditAccount);
    }

    /// @dev Sends an order to withdraw liquidity from a Balancer pool, burning BPT and receiving a single asset
    /// @param poolId ID of the pool to withdraw from
    /// @param assetOut Asset to withdraw
    /// @param amountIn Amount of BPT to burn
    /// @param minAmountOut Minimal amount of asset to receive
    function exitPoolSingleAsset(
        bytes32 poolId,
        IAsset assetOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );

        (address bpt, ) = IBalancerV2Vault(targetContract).getPool(poolId);

        _safeExecuteFastCheck(
            creditAccount,
            bpt,
            address(assetOut),
            abi.encodeWithSelector(
                IBalancerV2Vault.exitPool.selector,
                poolId,
                creditAccount,
                creditAccount,
                _getExitSingleAssetRequest(
                    poolId,
                    assetOut,
                    amountIn,
                    minAmountOut
                )
            ),
            false,
            false
        );
    }

    /// @dev Sends an order to withdraw liquidity from a Balancer pool, burning BPT and receiving a single asset
    /// @param poolId ID of the pool to withdraw from
    /// @param assetOut Asset to withdraw
    /// @param minRateRAY Minimal exchange rate of BPT to assetOut
    function exitPoolSingleAssetAll(
        bytes32 poolId,
        IAsset assetOut,
        uint256 minRateRAY
    ) external {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );

        (address bpt, ) = IBalancerV2Vault(targetContract).getPool(poolId);

        uint256 balanceInBefore = IERC20(bpt).balanceOf(creditAccount);

        if (balanceInBefore > 1) {
            unchecked {
                balanceInBefore--;
            }

            _safeExecuteFastCheck(
                creditAccount,
                bpt,
                address(assetOut),
                abi.encodeWithSignature(
                    "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
                    poolId,
                    creditAccount,
                    creditAccount,
                    _getExitSingleAssetRequest(
                        poolId,
                        assetOut,
                        balanceInBefore,
                        (balanceInBefore * minRateRAY) / RAY
                    )
                ),
                false,
                true
            );
        }
    }

    /// @dev Internal function that builds an ExitPoolRequest struct for one-sided withdrawals
    function _getExitSingleAssetRequest(
        bytes32 poolId,
        IAsset assetOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal view returns (ExitPoolRequest memory request) {
        (IERC20[] memory tokens, , ) = IBalancerV2Vault(targetContract)
            .getPoolTokens(poolId);

        uint256 len = tokens.length;

        request.assets = new IAsset[](tokens.length);
        request.minAmountsOut = new uint256[](tokens.length);
        uint256 tokenIndex = tokens.length;

        for (uint256 i = 0; i < len; ) {
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

    /// @dev Internal function that changes approval for a batch of assets in the vault
    function _approveAssets(
        IAsset[] memory assets,
        int256[] memory filter,
        uint256 amount
    ) internal {
        uint256 len = assets.length;

        for (uint256 i = 0; i < len; ) {
            if (filter[i] > 1) _approveToken(address(assets[i]), amount);

            unchecked {
                ++i;
            }
        }
    }

    function _approveAssets(
        IAsset[] memory assets,
        uint256[] memory filter,
        uint256 amount
    ) internal {
        uint256 len = assets.length;

        for (uint256 i = 0; i < len; ) {
            if (filter[i] > 1) _approveToken(address(assets[i]), amount);

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Internal function to enable a token on a CA
    function _enableToken(
        address creditAccount,
        address tokenToEnable
    ) internal {
        creditManager.checkAndEnableToken(creditAccount, tokenToEnable);
    }

    /// @dev Internal function to enable a batch of tokens on a CA, based on balances / balance changes
    function _enableAssets(
        address creditAccount,
        IAsset[] memory assets,
        int256[] memory filter
    ) internal {
        uint256 len = assets.length;

        for (uint256 i = 0; i < len; ) {
            if (filter[i] < -1) {
                creditManager.checkAndEnableToken(
                    creditAccount,
                    address(assets[i])
                );
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Internal function that creates a filter based on CA token balances
    function _getBalancesFilter(
        address creditAccount,
        IAsset[] memory assets
    ) internal view returns (int256[] memory filter) {
        uint256 len = assets.length;

        filter = new int256[](len);

        for (uint256 i = 0; i < len; ) {
            filter[i] = -int256(
                IERC20(address(assets[i])).balanceOf(creditAccount)
            );

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Returns a standard FundManagement struct used by the adapter
    function _getDefaultFundManagement(
        address creditAccount
    ) internal pure returns (FundManagement memory) {
        return
            FundManagement({
                sender: creditAccount,
                fromInternalBalance: false,
                recipient: payable(creditAccount),
                toInternalBalance: false
            });
    }

    /// @dev Returns the address and specialization of the pool, based on ID
    /// @param poolId ID of Balancer pool to query
    function getPool(
        bytes32 poolId
    ) external view returns (address, PoolSpecialization) {
        return IBalancerV2Vault(targetContract).getPool(poolId);
    }

    /// @dev Returns the data for a single asset in the pool
    /// @param poolId ID of Balancer pool to query
    /// @param token Token to query
    function getPoolTokenInfo(
        bytes32 poolId,
        IERC20 token
    )
        external
        view
        returns (
            uint256 cash,
            uint256 managed,
            uint256 lastChangeBlock,
            address assetManager
        )
    {
        return IBalancerV2Vault(targetContract).getPoolTokenInfo(poolId, token);
    }

    /// @dev Returns the pool tokens, based on pool ID
    /// @param poolId ID of Balancer pool to query
    function getPoolTokens(
        bytes32 poolId
    )
        external
        view
        returns (
            IERC20[] memory tokens,
            uint256[] memory balances,
            uint256 lastChangeBlock
        )
    {
        return IBalancerV2Vault(targetContract).getPoolTokens(poolId);
    }
}
