// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IEqualizerRouter, Route} from "../../integrations/equalizer/IEqualizerRouter.sol";
import {
    IEqualizerRouterAdapter,
    EqualizerPoolStatus,
    EqualizerPool
} from "../../interfaces/equalizer/IEqualizerRouterAdapter.sol";

/// @title Equalizer Router adapter
/// @notice Implements logic allowing CAs to perform swaps via Equalizer
contract EqualizerRouterAdapter is AbstractAdapter, IEqualizerRouterAdapter {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 public constant override contractType = "ADAPTER::EQUALIZER_ROUTER";
    uint256 public constant override version = 3_10;

    /// @dev Mapping from hash(token0, token1, stable) to respective tuple
    mapping(bytes32 => EqualizerPool) internal _hashToPool;

    /// @dev Set of hashes of (token0, token1, stable) for all supported pools
    EnumerableSet.Bytes32Set internal _supportedPoolHashes;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _router Equalizer Router address
    constructor(address _creditManager, address _router) AbstractAdapter(_creditManager, _router) {}

    /// @notice Swap given amount of input token to output token
    /// @param amountIn Amount of input token to spend
    /// @param amountOutMin Minumum amount of output token to receive
    /// @param routes Array of Route structs representing a swap path
    /// @param deadline Maximum timestamp until which the transaction is valid
    /// @dev Parameter `to` is ignored since swap recipient can only be the credit account
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address,
        uint256 deadline
    ) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();

        (bool valid, address tokenIn) = _validatePath(routes);
        if (!valid) revert InvalidPathException();

        _executeSwapSafeApprove(
            tokenIn,
            abi.encodeCall(
                IEqualizerRouter.swapExactTokensForTokens, (amountIn, amountOutMin, routes, creditAccount, deadline)
            )
        );

        return true;
    }

    /// @notice Swap the entire balance of input token to output token, except the specified amount
    /// @param leftoverAmount Amount of tokenIn to keep on the account
    /// @param rateMinRAY Minimum exchange rate between input and output tokens, scaled by 1e27
    /// @param routes Array of Route structs representing a swap path
    /// @param deadline Maximum timestamp until which the transaction is valid
    function swapDiffTokensForTokens(
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        Route[] calldata routes,
        uint256 deadline
    ) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();

        (bool valid, address tokenIn) = _validatePath(routes);
        if (!valid) revert InvalidPathException();

        uint256 amount = IERC20(tokenIn).balanceOf(creditAccount);
        if (amount <= leftoverAmount) return false;

        unchecked {
            amount -= leftoverAmount;
        }

        _executeSwapSafeApprove(
            tokenIn,
            abi.encodeCall(
                IEqualizerRouter.swapExactTokensForTokens,
                (amount, (amount * rateMinRAY) / RAY, routes, creditAccount, deadline)
            )
        );

        return true;
    }

    // ---- //
    // DATA //
    // ---- //

    function supportedPools() public view returns (EqualizerPool[] memory pools) {
        bytes32[] memory poolHashes = _supportedPoolHashes.values();
        uint256 len = poolHashes.length;

        pools = new EqualizerPool[](len);

        for (uint256 i = 0; i < len; ++i) {
            pools[i] = _hashToPool[poolHashes[i]];
        }
    }

    function serialize() external view returns (bytes memory serializedData) {
        EqualizerPool[] memory pools = supportedPools();
        serializedData = abi.encode(creditManager, targetContract, pools);
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Returns whether the (token0, token1) pair is allowed to be traded through the adapter
    function isPoolAllowed(address token0, address token1, bool stable) public view override returns (bool) {
        (token0, token1) = _sortTokens(token0, token1);
        return _supportedPoolHashes.contains(keccak256(abi.encode(token0, token1, stable)));
    }

    /// @notice Sets status for a batch of pools
    /// @param pools Array of `EqualizerPoolStatus` objects
    function setPoolStatusBatch(EqualizerPoolStatus[] calldata pools) external override configuratorOnly {
        uint256 len = pools.length;
        for (uint256 i; i < len; ++i) {
            (address token0, address token1) = _sortTokens(pools[i].token0, pools[i].token1);
            bytes32 poolHash = keccak256(abi.encode(token0, token1, pools[i].stable));
            if (pools[i].allowed) {
                _getMaskOrRevert(token0);
                _getMaskOrRevert(token1);

                _supportedPoolHashes.add(poolHash);
                _hashToPool[poolHash] = EqualizerPool({token0: token0, token1: token1, stable: pools[i].stable});
            } else {
                _supportedPoolHashes.remove(poolHash);
                delete _hashToPool[poolHash];
            }
            emit SetPoolStatus(token0, token1, pools[i].stable, pools[i].allowed);
        }
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Performs sanity check on a swap path, if path is valid also returns input token
    ///      - Path length must be no more than 3 (i.e., at most 3 hops)
    ///      - Each swap must be through an allowed pool
    function _validatePath(Route[] memory routes) internal view returns (bool valid, address tokenIn) {
        uint256 len = routes.length;
        if (len < 1 || len > 3) return (false, tokenIn);

        tokenIn = routes[0].from;
        valid = isPoolAllowed(routes[0].from, routes[0].to, routes[0].stable);

        for (uint256 i = 1; i < len && valid; i++) {
            valid =
                isPoolAllowed(routes[i].from, routes[i].to, routes[i].stable) && (routes[i - 1].to == routes[i].from);
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
}
