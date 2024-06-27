// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {IVelodromeV2Router, Route} from "../../integrations/velodrome/IVelodromeV2Router.sol";
import {
    IVelodromeV2RouterAdapter,
    VelodromeV2PoolStatus,
    VelodromeV2Pool
} from "../../interfaces/velodrome/IVelodromeV2RouterAdapter.sol";

/// @title Velodrome V2 Router adapter
/// @notice Implements logic allowing CAs to perform swaps via Velodrome V2
contract VelodromeV2RouterAdapter is AbstractAdapter, IVelodromeV2RouterAdapter {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    uint256 public constant override adapterType = uint256(AdapterType.VELODROME_V2_ROUTER);
    uint256 public constant override version = 3_00;

    /// @dev Mapping from hash(token0, token1, stable, factory) to respective tuple
    mapping(bytes32 => VelodromeV2Pool) internal _hashToPool;

    /// @dev Set of hashes of (token0, token1, stable, factory) for all supported pools
    EnumerableSet.Bytes32Set internal _supportedPoolHashes;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _router Velodrome V2 Router address
    constructor(address _creditManager, address _router)
        AbstractAdapter(_creditManager, _router) // U: [VELO2-01]
    {}

    /// @notice Swap given amount of input token to output token
    /// @param amountIn Amount of input token to spend
    /// @param amountOutMin Minumum amount of output token to receive
    /// @param routes Array of Route structs representing a swap path, must have at most 3 elements
    /// @param deadline Maximum timestamp until which the transaction is valid
    /// @dev Parameter `to` is ignored since swap recipient can only be the credit account
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address,
        uint256 deadline
    )
        external
        override
        creditFacadeOnly // U: [VELO2-02]
        returns (bool)
    {
        address creditAccount = _creditAccount();

        (bool valid, address tokenIn) = _validatePath(routes); // U: [VELO2-06]
        if (!valid) revert InvalidPathException();

        _executeSwapSafeApprove(
            tokenIn,
            abi.encodeCall(
                IVelodromeV2Router.swapExactTokensForTokens, (amountIn, amountOutMin, routes, creditAccount, deadline)
            )
        ); // U: [VELO2-03]

        return true;
    }

    /// @notice Swap the entire balance of input token to output token, except the specified amount
    /// @param leftoverAmount Amount of tokenIn to keep on the account
    /// @param rateMinRAY Minimum exchange rate between input and output tokens, scaled by 1e27
    /// @param routes Array of Route structs representing a swap path, must have at most 3 elements
    /// @param deadline Maximum timestamp until which the transaction is valid
    function swapDiffTokensForTokens(
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        Route[] calldata routes,
        uint256 deadline
    )
        external
        override
        creditFacadeOnly // U: [VELO2-02]
        returns (bool)
    {
        address creditAccount = _creditAccount();

        (bool valid, address tokenIn) = _validatePath(routes); // U: [VELO2-06]
        if (!valid) revert InvalidPathException();

        uint256 amount = IERC20(tokenIn).balanceOf(creditAccount);
        if (amount <= leftoverAmount) return false;

        unchecked {
            amount -= leftoverAmount; // U: [VELO2-04]
        }

        _executeSwapSafeApprove(
            tokenIn,
            abi.encodeCall(
                IVelodromeV2Router.swapExactTokensForTokens,
                (amount, (amount * rateMinRAY) / RAY, routes, creditAccount, deadline)
            )
        ); // U: [VELO2-04]

        return true;
    }

    // ---- //
    // DATA //
    // ---- //

    function supportedPools() public view returns (VelodromeV2Pool[] memory pools) {
        bytes32[] memory poolHashes = _supportedPoolHashes.values();
        uint256 len = poolHashes.length;

        pools = new VelodromeV2Pool[](len);

        for (uint256 i = 0; i < len; ++i) {
            pools[i] = _hashToPool[poolHashes[i]];
        }
    }

    /// @notice Returns all adapter parameters serialized into a bytes array,
    ///         as well as adapter type and version, to properly deserialize
    function serialize() external view override returns (bytes memory serializedData) {
        VelodromeV2Pool[] memory pools = supportedPools();
        serializedData = abi.encode(creditManager, targetContract, pools);
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Returns whether the (token0, token1) pair is allowed to be traded through the adapter
    function isPoolAllowed(address token0, address token1, bool stable, address factory)
        public
        view
        override
        returns (bool)
    {
        (token0, token1) = _sortTokens(token0, token1);
        return _supportedPoolHashes.contains(keccak256(abi.encode(token0, token1, stable, factory)));
    }

    /// @notice Sets status for a batch of pools
    /// @param pools Array of `VelodromeV2PoolStatus` objects
    function setPoolStatusBatch(VelodromeV2PoolStatus[] calldata pools) external override configuratorOnly {
        uint256 len = pools.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                (address token0, address token1) = _sortTokens(pools[i].token0, pools[i].token1);
                bytes32 poolHash = keccak256(abi.encode(token0, token1, pools[i].stable, pools[i].factory));
                if (pools[i].allowed) {
                    /// For each added pool, we verify that the pool tokens are valid collaterals,
                    /// as otherwise operations with unsupported tokens would be possible, leading
                    /// to possibility of control flow capture
                    _getMaskOrRevert(token0);
                    _getMaskOrRevert(token1);

                    _supportedPoolHashes.add(poolHash);
                    _hashToPool[poolHash] = VelodromeV2Pool({
                        token0: token0,
                        token1: token1,
                        stable: pools[i].stable,
                        factory: pools[i].factory
                    });
                } else {
                    _supportedPoolHashes.remove(poolHash);
                    delete _hashToPool[poolHash];
                }
                emit SetPoolStatus(token0, token1, pools[i].stable, pools[i].factory, pools[i].allowed); // U: [VELO2-05]
            }
        }
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Performs sanity check on a swap path, if path is valid also returns input and output tokens
    ///      - Path length must be no more than 4 (i.e., at most 3 hops)
    ///      - Each swap must be through an allowed pool
    function _validatePath(Route[] memory routes) internal view returns (bool valid, address tokenIn) {
        uint256 len = routes.length;
        if (len < 1 || len > 3) return (false, tokenIn);

        tokenIn = routes[0].from;
        valid = isPoolAllowed(routes[0].from, routes[0].to, routes[0].stable, routes[0].factory);
        if (valid && len > 1) {
            valid = isPoolAllowed(routes[1].from, routes[1].to, routes[1].stable, routes[1].factory)
                && (routes[0].to == routes[1].from);
            if (valid && len > 2) {
                valid = isPoolAllowed(routes[2].from, routes[2].to, routes[2].stable, routes[2].factory)
                    && (routes[1].to == routes[2].from);
            }
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
