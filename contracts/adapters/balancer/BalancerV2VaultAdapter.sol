// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {BitMask} from "@gearbox-protocol/core-v3/contracts/libraries/BitMask.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

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
import {
    IBalancerV2VaultAdapter, SingleSwapDiff, PoolStatus
} from "../../interfaces/balancer/IBalancerV2VaultAdapter.sol";

/// @title Balancer V2 Vault adapter
/// @notice Implements logic allowing CAs to swap through and LP in Balancer vaults
contract BalancerV2VaultAdapter is AbstractAdapter, IBalancerV2VaultAdapter {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using BitMask for uint256;

    uint256 public constant override adapterType = uint256(AdapterType.BALANCER_VAULT);
    uint256 public constant override version = 3_10;

    /// @notice Mapping from poolId to status of the pool: whether it is not supported, fully supported or swap-only
    mapping(bytes32 => PoolStatus) public override poolStatus;

    /// @dev Set of pool ids with "ALLOW" and "SWAP_ONLY" status
    EnumerableSet.Bytes32Set internal _supportedPoolIds;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _vault Balancer vault address
    constructor(address _creditManager, address _vault)
        AbstractAdapter(_creditManager, _vault) // U:[BAL2-1]
    {}

    // ----- //
    // SWAPS //
    // ----- //

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
    /// @dev The function reverts if the poolId status is not ALLOWED or SWAP_ONLY
    function swap(SingleSwap memory singleSwap, FundManagement memory, uint256 limit, uint256 deadline)
        external
        override
        creditFacadeOnly // U:[BAL2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        if (poolStatus[singleSwap.poolId] == PoolStatus.NOT_ALLOWED) {
            revert PoolNotSupportedException(); // U:[BAL2-3]
        }

        address creditAccount = _creditAccount(); // U:[BAL2-3]

        address tokenIn = address(singleSwap.assetIn);
        address tokenOut = address(singleSwap.assetOut);

        FundManagement memory fundManagement = _getDefaultFundManagement(creditAccount); // U:[BAL2-3]

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            tokenIn,
            tokenOut,
            abi.encodeCall(IBalancerV2Vault.swap, (singleSwap, fundManagement, limit, deadline)),
            false
        ); // U:[BAL2-3]
    }

    /// @notice Swaps the entire balance of a token for another token within a single pool, except the specified amount
    /// @param singleSwapDiff Struct containing swap parameters
    ///        * `poolId` - ID of the pool to perform a swap in
    ///        * `leftoverAmount` - amount of assetIn to leave after operation
    ///        * `assetIn` - asset to send
    ///        * `assetOut` - asset to receive
    ///        * `userData` - additional generic blob used to pass extra data
    /// @param limitRateRAY The minimal resulting exchange rate of assetOut to assetIn, scaled by 1e27
    /// @param deadline The latest timestamp at which the swap would be executed
    /// @dev The function reverts if the poolId status is not ALLOWED or SWAP_ONLY
    function swapDiff(SingleSwapDiff memory singleSwapDiff, uint256 limitRateRAY, uint256 deadline)
        external
        override
        creditFacadeOnly // U:[BAL2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[BAL2-4]

        if (poolStatus[singleSwapDiff.poolId] == PoolStatus.NOT_ALLOWED) {
            revert PoolNotSupportedException(); // U:[BAL2-4]
        }

        uint256 amount = IERC20(address(singleSwapDiff.assetIn)).balanceOf(creditAccount); // U:[BAL2-4]
        if (amount <= singleSwapDiff.leftoverAmount) return (0, 0);

        unchecked {
            amount -= singleSwapDiff.leftoverAmount; // U:[BAL2-4]
        }

        FundManagement memory fundManagement = _getDefaultFundManagement(creditAccount); // U:[BAL2-4]

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            address(singleSwapDiff.assetIn),
            address(singleSwapDiff.assetOut),
            abi.encodeCall(
                IBalancerV2Vault.swap,
                (
                    SingleSwap({
                        poolId: singleSwapDiff.poolId,
                        kind: SwapKind.GIVEN_IN,
                        assetIn: singleSwapDiff.assetIn,
                        assetOut: singleSwapDiff.assetOut,
                        amount: amount,
                        userData: singleSwapDiff.userData
                    }),
                    fundManagement,
                    (amount * limitRateRAY) / RAY,
                    deadline
                )
            ),
            singleSwapDiff.leftoverAmount <= 1
        ); // U:[BAL2-4]
    }

    /// @notice Performs a multi-hop swap through several Balancer pools
    /// @param kind Type of swap (GIVEN IN or GIVEN OUT)
    /// @param swaps Array of structs containing data for each individual swap:
    ///        * `poolId` - ID of the pool to perform a swap in
    ///        * `assetInIndex` - Index of the input asset in the pool (in an alphanumerically sorted array of asset addresses)
    ///        * `assetOutIndex` - Index of the output asset in the pool (in an alphanumerically sorted array of asset addresses)
    ///        * `amount` - amount of asset to send / receive. 0 signals to either spend the entire amount received from the last step,
    ///           or to receive the exact amount needed for the next step
    ///        * `userData` - generic blob used to pass extra data
    /// @param assets Array of all assets participating in the swap
    /// @param limits Array of minimal received (negative) / maximal spent (positive) amounts, in the same order as the assets array
    /// @param deadline The latest timestamp at which the swap would be executed
    /// @dev `fundManagement` param from the original interface is ignored, as the adapter does not use internal balances and
    ///       only has one sender/recipient
    /// @dev The function reverts if any of the poolId statuses is not ALLOWED or SWAP_ONLY
    function batchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        FundManagement memory,
        int256[] memory limits,
        uint256 deadline
    )
        external
        override
        creditFacadeOnly // U:[BAL2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        for (uint256 i; i < swaps.length; ++i) {
            if (poolStatus[swaps[i].poolId] == PoolStatus.NOT_ALLOWED) {
                revert PoolNotSupportedException(); // U:[BAL2-5]
            }
        }

        address creditAccount = _creditAccount(); // U:[BAL2-5]

        FundManagement memory fundManagement = _getDefaultFundManagement(creditAccount); // U:[BAL2-5]

        _approveAssets(assets, limits, type(uint256).max); // U:[BAL2-5]

        int256[] memory assetDeltas = abi.decode(
            _execute(
                abi.encodeCall(IBalancerV2Vault.batchSwap, (kind, swaps, assets, fundManagement, limits, deadline))
            ),
            (int256[])
        ); // U:[BAL2-5]

        _approveAssets(assets, limits, 1); // U:[BAL2-5]

        (tokensToEnable, tokensToDisable) = (_getTokensToEnable(assets, assetDeltas), 0); // U:[BAL2-5]
    }

    // --------- //
    // JOIN POOL //
    // --------- //

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
    /// @dev The function reverts if poolId status is not ALLOWED
    function joinPool(bytes32 poolId, address, address, JoinPoolRequest memory request)
        external
        override
        creditFacadeOnly // U:[BAL2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        if (poolStatus[poolId] != PoolStatus.ALLOWED) {
            revert PoolNotSupportedException(); // U:[BAL2-6]
        }

        address creditAccount = _creditAccount(); // U:[BAL2-6]

        (address bpt,) = IBalancerV2Vault(targetContract).getPool(poolId);

        request.fromInternalBalance = false; // U:[BAL2-6]

        _approveAssets(request.assets, request.maxAmountsIn, type(uint256).max); // U:[BAL2-6]
        _execute(abi.encodeCall(IBalancerV2Vault.joinPool, (poolId, creditAccount, creditAccount, request))); // U:[BAL2-6]
        _approveAssets(request.assets, request.maxAmountsIn, 1); // U:[BAL2-6]
        (tokensToEnable, tokensToDisable) = (_getMaskOrRevert(bpt), 0); // U:[BAL2-6]
    }

    /// @notice Deposits single asset as liquidity into a Balancer pool
    /// @param poolId ID of the pool to deposit into
    /// @param assetIn Asset to deposit
    /// @param amountIn Amount of asset to deposit
    /// @param minAmountOut The minimal amount of BPT to receive
    /// @dev The function reverts if poolId status is not ALLOWED
    function joinPoolSingleAsset(bytes32 poolId, IAsset assetIn, uint256 amountIn, uint256 minAmountOut)
        external
        override
        creditFacadeOnly // U:[BAL2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        if (poolStatus[poolId] != PoolStatus.ALLOWED) {
            revert PoolNotSupportedException(); // U:[BAL2-7]
        }

        address creditAccount = _creditAccount(); // U:[BAL2-7]

        (address bpt,) = IBalancerV2Vault(targetContract).getPool(poolId);

        // calling `_executeSwap` because we need to check if BPT is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            address(assetIn),
            bpt,
            abi.encodeCall(
                IBalancerV2Vault.joinPool,
                (
                    poolId,
                    creditAccount,
                    creditAccount,
                    _getJoinSingleAssetRequest(poolId, assetIn, amountIn, minAmountOut, bpt)
                )
            ),
            false
        ); // U:[BAL2-7]
    }

    /// @notice Deposits the entire balance of given asset, except a specified amount, as liquidity into a Balancer pool
    /// @param poolId ID of the pool to deposit into
    /// @param assetIn Asset to deposit
    /// @param leftoverAmount Amount of underlying to keep on the account
    /// @param minRateRAY The minimal exchange rate of assetIn to BPT, scaled by 1e27
    /// @dev The function reverts if poolId status is not ALLOWED
    function joinPoolSingleAssetDiff(bytes32 poolId, IAsset assetIn, uint256 leftoverAmount, uint256 minRateRAY)
        external
        override
        creditFacadeOnly // U:[BAL2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[BAL2-8]

        if (poolStatus[poolId] != PoolStatus.ALLOWED) {
            revert PoolNotSupportedException(); // U:[BAL2-8]
        }

        uint256 amount = IERC20(address(assetIn)).balanceOf(creditAccount); // U:[BAL2-8]
        if (amount <= leftoverAmount) return (0, 0);

        unchecked {
            amount -= leftoverAmount; // U:[BAL2-8]
        }

        (address bpt,) = IBalancerV2Vault(targetContract).getPool(poolId);

        uint256 amountOutMin = (amount * minRateRAY) / RAY; // U:[BAL2-8]
        JoinPoolRequest memory request = _getJoinSingleAssetRequest(poolId, assetIn, amount, amountOutMin, bpt); // U:[BAL2-8]

        // calling `_executeSwap` because we need to check if BPT is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            address(assetIn),
            bpt,
            abi.encodeCall(IBalancerV2Vault.joinPool, (poolId, creditAccount, creditAccount, request)),
            leftoverAmount <= 1
        ); // U:[BAL2-8]
    }

    /// @dev Internal function that builds a `JoinPoolRequest` struct for one-sided deposits
    function _getJoinSingleAssetRequest(
        bytes32 poolId,
        IAsset assetIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address bpt
    ) internal view returns (JoinPoolRequest memory request) {
        (IERC20[] memory tokens,,) = IBalancerV2Vault(targetContract).getPoolTokens(poolId);

        uint256 len = tokens.length;

        request.assets = new IAsset[](tokens.length);
        request.maxAmountsIn = new uint256[](tokens.length);
        uint256 bptIndex = tokens.length;

        for (uint256 i; i < len; ++i) {
            request.assets[i] = IAsset(address(tokens[i]));

            if (request.assets[i] == assetIn) {
                request.maxAmountsIn[i] = amountIn; // U:[BAL2-7,8]
            }

            if (address(request.assets[i]) == bpt) {
                bptIndex = i;
            }
        }

        request.userData = abi.encode(uint256(1), _removeIndex(request.maxAmountsIn, bptIndex), minAmountOut); // U:[BAL2-7,8]
    }

    // --------- //
    // EXIT POOL //
    // --------- //

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
        creditFacadeOnly // U:[BAL2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[BAL2-9]

        (address bpt,) = IBalancerV2Vault(targetContract).getPool(poolId);

        request.toInternalBalance = false; // U:[BAL2-9]

        _execute(abi.encodeCall(IBalancerV2Vault.exitPool, (poolId, creditAccount, payable(creditAccount), request))); // U:[BAL2-9]

        _getMaskOrRevert(bpt); // U:[BAL2-9]
        (tokensToEnable, tokensToDisable) =
            (_getTokensToEnable(request.assets, _getBalancesFilter(creditAccount, request.assets)), 0); // U:[BAL2-9]
    }

    /// @notice Withdraws liquidity from a Balancer pool, burning BPT and receiving a single asset
    /// @param poolId ID of the pool to withdraw from
    /// @param assetOut Asset to withdraw
    /// @param amountIn Amount of BPT to burn
    /// @param minAmountOut Minimal amount of asset to receive
    function exitPoolSingleAsset(bytes32 poolId, IAsset assetOut, uint256 amountIn, uint256 minAmountOut)
        external
        override
        creditFacadeOnly // U:[BAL2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[BAL2-10]

        (address bpt,) = IBalancerV2Vault(targetContract).getPool(poolId);

        // calling `_executeSwap` because we need to check if asset is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapNoApprove(
            bpt,
            address(assetOut),
            abi.encodeCall(
                IBalancerV2Vault.exitPool,
                (
                    poolId,
                    creditAccount,
                    payable(creditAccount),
                    _getExitSingleAssetRequest(poolId, assetOut, amountIn, minAmountOut, bpt)
                )
            ),
            false
        ); // U:[BAL2-10]
    }

    /// @notice Withdraws all liquidity from a Balancer pool except the specified amount, burning BPT and receiving a single asset
    /// @param poolId ID of the pool to withdraw from
    /// @param assetOut Asset to withdraw
    /// @param leftoverAmount Amount of pool token to keep on the account
    /// @param minRateRAY Minimal exchange rate of BPT to assetOut, scaled by 1e27
    function exitPoolSingleAssetDiff(bytes32 poolId, IAsset assetOut, uint256 leftoverAmount, uint256 minRateRAY)
        external
        override
        creditFacadeOnly // U:[BAL2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[BAL2-11]

        (address bpt,) = IBalancerV2Vault(targetContract).getPool(poolId);

        uint256 amount = IERC20(bpt).balanceOf(creditAccount); // U:[BAL2-11]
        if (amount <= leftoverAmount) return (0, 0);

        unchecked {
            amount -= leftoverAmount; // U:[BAL2-11]
        }

        uint256 amountOutMin = (amount * minRateRAY) / RAY; // U:[BAL2-11]
        ExitPoolRequest memory request = _getExitSingleAssetRequest(poolId, assetOut, amount, amountOutMin, bpt); // U:[BAL2-11]

        // calling `_executeSwap` because we need to check if asset is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapNoApprove(
            bpt,
            address(assetOut),
            abi.encodeCall(IBalancerV2Vault.exitPool, (poolId, creditAccount, payable(creditAccount), request)),
            leftoverAmount <= 1
        ); // U:[BAL2-11]
    }

    /// @dev Internal function that builds an `ExitPoolRequest` struct for one-sided withdrawals
    function _getExitSingleAssetRequest(
        bytes32 poolId,
        IAsset assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address bpt
    ) internal view returns (ExitPoolRequest memory request) {
        (IERC20[] memory tokens,,) = IBalancerV2Vault(targetContract).getPoolTokens(poolId);

        uint256 len = tokens.length;

        request.assets = new IAsset[](tokens.length);
        request.minAmountsOut = new uint256[](tokens.length);
        uint256 tokenIndex = tokens.length;
        uint256 bptIndex = tokens.length;

        for (uint256 i; i < len; ++i) {
            request.assets[i] = IAsset(address(tokens[i]));

            if (request.assets[i] == assetOut) {
                request.minAmountsOut[i] = minAmountOut; // U:[BAL2-10,11]
                tokenIndex = i;
            }

            if (address(request.assets[i]) == bpt) {
                bptIndex = i;
            }
        }

        tokenIndex = tokenIndex > bptIndex ? tokenIndex - 1 : tokenIndex; // U:[BAL2-10,11]

        request.userData = abi.encode(uint256(0), amountIn, tokenIndex);
    }

    // ---- //
    // DATA //
    // ---- //

    /// @notice Returns the set of all supported pool IDs
    function supportedPoolIds() public view returns (bytes32[] memory poolIds) {
        return _supportedPoolIds.values();
    }

    /// @notice Returns all adapter parameters serialized into a bytes array,
    ///         as well as adapter type and version, to properly deserialize
    function serialize() external view override returns (bytes memory serializedData) {
        bytes32[] memory supportedIDs = supportedPoolIds();
        PoolStatus[] memory supportedPoolStatus = new PoolStatus[](supportedIDs.length);

        for (uint256 i = 0; i < supportedIDs.length; ++i) {
            supportedPoolStatus[i] = poolStatus[supportedIDs[i]];
        }

        serializedData = abi.encode(creditManager, targetContract, supportedIDs, supportedPoolStatus);
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Internal function that changes approval for a batch of assets in the vault
    function _approveAssets(IAsset[] memory assets, int256[] memory filter, uint256 amount) internal {
        uint256 len = assets.length;

        for (uint256 i; i < len; ++i) {
            if (filter[i] > 1) _approveToken(address(assets[i]), amount);
        }
    }

    /// @dev Internal function that changes approval for a batch of assets in the vault (overloading)
    function _approveAssets(IAsset[] memory assets, uint256[] memory filter, uint256 amount) internal {
        uint256 len = assets.length;

        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                if (filter[i] > 1) _approveToken(address(assets[i]), amount);
            }
        }
    }

    /// @dev Returns mask of all tokens that should be enabled, based on balances / balance changes
    function _getTokensToEnable(IAsset[] memory assets, int256[] memory filter)
        internal
        view
        returns (uint256 tokensToEnable)
    {
        uint256 len = assets.length;

        unchecked {
            for (uint256 i; i < len; ++i) {
                if (filter[i] < -1) tokensToEnable = tokensToEnable.enable(_getMaskOrRevert(address(assets[i])));
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

        for (uint256 i; i < len; ++i) {
            filter[i] = -int256(IERC20(address(assets[i])).balanceOf(creditAccount));
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

    /// @dev Returns copy of `array` without an element at `index`
    function _removeIndex(uint256[] memory array, uint256 index) internal pure returns (uint256[] memory res) {
        uint256 len = array.length;

        if (index >= len) {
            return array;
        }

        len--;

        res = new uint256[](len);

        for (uint256 i = 0; i < len; ++i) {
            if (i < index) {
                res[i] = array[i];
            } else {
                res[i] = array[i + 1];
            }
        }
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Sets the pool status
    function setPoolStatus(bytes32 poolId, PoolStatus newStatus)
        external
        override
        configuratorOnly // U:[BAL2-12]
    {
        if (poolStatus[poolId] != newStatus) {
            if (newStatus == PoolStatus.ALLOWED || newStatus == PoolStatus.SWAP_ONLY) {
                _supportedPoolIds.add(poolId);
            } else {
                _supportedPoolIds.remove(poolId);
            }

            poolStatus[poolId] = newStatus; // U:[BAL2-12]
            emit SetPoolStatus(poolId, newStatus); // U:[BAL2-12]
        }
    }
}
