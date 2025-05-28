// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {BitMask} from "@gearbox-protocol/core-v3/contracts/libraries/BitMask.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {ITraderJoeRouter, Path, Version} from "../../integrations/traderjoe/ITraderJoeRouter.sol";
import {
    ITraderJoeRouterAdapter,
    TraderJoePoolStatus,
    TraderJoePool
} from "../../interfaces/traderjoe/ITraderJoeRouterAdapter.sol";

/// @title TraderJoe Router adapter
/// @notice Implements logic allowing CAs to perform swaps via TraderJoe
contract TraderJoeRouterAdapter is AbstractAdapter, ITraderJoeRouterAdapter {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using BitMask for uint256;

    bytes32 public constant override contractType = "ADAPTER::TRADERJOE_ROUTER";
    uint256 public constant override version = 3_10;

    /// @dev Mapping from hash(token0, token1, binStep, poolVersion) to respective tuple
    mapping(bytes32 => TraderJoePool) internal _hashToPool;

    /// @dev Set of hashes of (token0, token1, binStep, poolVersion) for all supported pools
    EnumerableSet.Bytes32Set internal _supportedPoolHashes;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _router TraderJoe Router address
    constructor(address _creditManager, address _router) AbstractAdapter(_creditManager, _router) {}

    /// @notice Swap exact tokens for tokens
    /// @param amountIn Amount of input token to spend
    /// @param amountOutMin Minimum amount of output token to receive
    /// @param path Path struct defining the swap route
    /// @param deadline Maximum timestamp until which the transaction is valid
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Path calldata path,
        address,
        uint256 deadline
    ) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();

        (bool valid, address tokenIn) = _validatePath(path);
        if (!valid) revert InvalidPathException();

        _executeSwapSafeApprove(
            tokenIn,
            abi.encodeCall(
                ITraderJoeRouter.swapExactTokensForTokens, (amountIn, amountOutMin, path, creditAccount, deadline)
            )
        );

        return true;
    }

    /// @notice Swap exact tokens for tokens supporting fee-on-transfer tokens
    /// @param amountIn Amount of input token to spend
    /// @param amountOutMin Minimum amount of output token to receive
    /// @param path Path struct defining the swap route
    /// @param deadline Maximum timestamp until which the transaction is valid
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Path calldata path,
        address,
        uint256 deadline
    ) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();

        (bool valid, address tokenIn) = _validatePath(path);
        if (!valid) revert InvalidPathException();

        _executeSwapSafeApprove(
            tokenIn,
            abi.encodeCall(
                ITraderJoeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens,
                (amountIn, amountOutMin, path, creditAccount, deadline)
            )
        );

        return true;
    }

    /// @notice Swap the entire balance of input token to output token, except the specified amount
    /// @param leftoverAmount Amount of tokenIn to keep on the account
    /// @param rateMinRAY Minimum exchange rate between input and output tokens, scaled by 1e27
    /// @param path Path struct defining the swap route
    /// @param deadline Maximum timestamp until which the transaction is valid
    function swapDiffTokensForTokens(uint256 leftoverAmount, uint256 rateMinRAY, Path calldata path, uint256 deadline)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        address creditAccount = _creditAccount();

        (bool valid, address tokenIn) = _validatePath(path);
        if (!valid) revert InvalidPathException();

        uint256 amount = IERC20(tokenIn).balanceOf(creditAccount);
        if (amount <= leftoverAmount) return false;

        unchecked {
            amount -= leftoverAmount;
        }

        uint256 amountOutMin = (amount * rateMinRAY) / RAY;

        _executeSwapSafeApprove(
            tokenIn,
            abi.encodeCall(
                ITraderJoeRouter.swapExactTokensForTokens, (amount, amountOutMin, path, creditAccount, deadline)
            )
        );

        return true;
    }

    /// @notice Swap the entire balance of input token to output token, except the specified amount
    /// Uses the fee-on-transfer version of the swap
    /// @param leftoverAmount Amount of tokenIn to keep on the account
    /// @param rateMinRAY Minimum exchange rate between input and output tokens, scaled by 1e27
    /// @param path Path struct defining the swap route
    /// @param deadline Maximum timestamp until which the transaction is valid
    function swapDiffTokensForTokensSupportingFeeOnTransferTokens(
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        Path calldata path,
        uint256 deadline
    ) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();

        (bool valid, address tokenIn) = _validatePath(path);
        if (!valid) revert InvalidPathException();

        uint256 amount = IERC20(tokenIn).balanceOf(creditAccount);
        if (amount <= leftoverAmount) return false;

        unchecked {
            amount -= leftoverAmount;
        }

        uint256 amountOutMin = (amount * rateMinRAY) / RAY;

        _executeSwapSafeApprove(
            tokenIn,
            abi.encodeCall(
                ITraderJoeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens,
                (amount, amountOutMin, path, creditAccount, deadline)
            )
        );

        return true;
    }

    // ---- //
    // DATA //
    // ---- //

    /// @notice Returns all supported pools
    function supportedPools() public view returns (TraderJoePool[] memory pools) {
        bytes32[] memory poolHashes = _supportedPoolHashes.values();
        uint256 len = poolHashes.length;

        pools = new TraderJoePool[](len);

        for (uint256 i = 0; i < len; ++i) {
            pools[i] = _hashToPool[poolHashes[i]];
        }
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        TraderJoePool[] memory pools = supportedPools();
        serializedData = abi.encode(creditManager, targetContract, pools);
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Returns whether the given pool parameters are allowed
    function isPoolAllowed(address token0, address token1, uint256 binStep, Version poolVersion)
        public
        view
        override
        returns (bool)
    {
        (token0, token1) = _sortTokens(token0, token1);
        return _supportedPoolHashes.contains(_computePoolHash(token0, token1, binStep, poolVersion));
    }

    /// @notice Sets status for a batch of pools
    /// @param pools Array of `TraderJoePoolStatus` objects
    function setPoolStatusBatch(TraderJoePoolStatus[] calldata pools) external override configuratorOnly {
        uint256 len = pools.length;
        for (uint256 i; i < len; ++i) {
            (address token0, address token1) = _sortTokens(pools[i].token0, pools[i].token1);
            bytes32 poolHash = _computePoolHash(token0, token1, pools[i].binStep, pools[i].poolVersion);

            if (pools[i].allowed) {
                _getMaskOrRevert(token0);
                _getMaskOrRevert(token1);

                _supportedPoolHashes.add(poolHash);
                _hashToPool[poolHash] = TraderJoePool({
                    token0: token0,
                    token1: token1,
                    binStep: pools[i].binStep,
                    poolVersion: pools[i].poolVersion
                });
            } else {
                _supportedPoolHashes.remove(poolHash);
                delete _hashToPool[poolHash];
            }
            emit SetPoolStatus(token0, token1, pools[i].binStep, pools[i].poolVersion, pools[i].allowed);
        }
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Performs sanity check on a swap path
    ///      - Path length must be reasonable (at most 3 hops, or 4 tokens)
    ///      - Each hop must be through an allowed pool
    function _validatePath(Path memory path) internal view returns (bool valid, address tokenIn) {
        uint256 len = path.tokenPath.length;
        if (len < 2 || len > 4) return (false, tokenIn);

        // Check if pairBinSteps and versions arrays have the correct length (tokens - 1)
        if (path.pairBinSteps.length != len - 1 || path.versions.length != len - 1) {
            return (false, tokenIn);
        }

        tokenIn = address(path.tokenPath[0]);
        valid = true;

        // Validate each hop in the path
        for (uint256 i = 0; i < len - 1 && valid; i++) {
            valid = isPoolAllowed(
                address(path.tokenPath[i]), address(path.tokenPath[i + 1]), path.pairBinSteps[i], path.versions[i]
            );
        }
    }

    /// @dev Sorts two token addresses
    function _sortTokens(address token0, address token1) internal pure returns (address, address) {
        if (uint160(token0) < uint160(token1)) {
            return (token0, token1);
        } else {
            return (token1, token0);
        }
    }

    /// @dev Returns the hash of a pool
    function _computePoolHash(address token0, address token1, uint256 binStep, Version poolVersion)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(token0, token1, binStep, poolVersion));
    }
}
