// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {IVelodromeV2Router, Route} from "../../integrations/velodrome/IVelodromeV2Router.sol";
import {
    IVelodromeV2RouterAdapter, VelodromeV2PoolStatus
} from "../../interfaces/velodrome/IVelodromeV2RouterAdapter.sol";

/// @title Velodrome V2 Router adapter
/// @notice Implements logic allowing CAs to perform swaps via Velodrome V2
contract VelodromeV2RouterAdapter is AbstractAdapter, IVelodromeV2RouterAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.VELODROME_V2_ROUTER;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @dev Mapping from (token0, token1, stable, factory) to whether the pool can be traded through the adapter
    mapping(address => mapping(address => mapping(bool => mapping(address => bool)))) internal _poolStatus;

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
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();

        (bool valid, address tokenIn, address tokenOut) = _validatePath(routes); // U: [VELO2-06]
        if (!valid) revert InvalidPathException();

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            tokenIn,
            tokenOut,
            abi.encodeCall(
                IVelodromeV2Router.swapExactTokensForTokens, (amountIn, amountOutMin, routes, creditAccount, deadline)
            ),
            false
        ); // U: [VELO2-03]
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
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();

        address tokenIn;
        address tokenOut;

        {
            bool valid;
            (valid, tokenIn, tokenOut) = _validatePath(routes); // U: [VELO2-06]
            if (!valid) revert InvalidPathException();
        }

        uint256 amount = IERC20(tokenIn).balanceOf(creditAccount);
        if (amount <= leftoverAmount) return (0, 0);

        unchecked {
            amount -= leftoverAmount; // U: [VELO2-04]
        }

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            tokenIn,
            tokenOut,
            abi.encodeCall(
                IVelodromeV2Router.swapExactTokensForTokens,
                (amount, (amount * rateMinRAY) / RAY, routes, creditAccount, deadline)
            ),
            leftoverAmount <= 1
        ); // U: [VELO2-04]
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
        return _poolStatus[token0][token1][stable][factory];
    }

    /// @notice Sets status for a batch of pools
    /// @param pools Array of `VelodromeV2PoolStatus` objects
    function setPoolStatusBatch(VelodromeV2PoolStatus[] calldata pools) external override configuratorOnly {
        uint256 len = pools.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                (address token0, address token1) = _sortTokens(pools[i].token0, pools[i].token1);
                _poolStatus[token0][token1][pools[i].stable][pools[i].factory] = pools[i].allowed; // U: [VELO2-05]
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
    function _validatePath(Route[] memory routes)
        internal
        view
        returns (bool valid, address tokenIn, address tokenOut)
    {
        uint256 len = routes.length;
        if (len < 1 || len > 3) return (false, tokenIn, tokenOut);

        tokenIn = routes[0].from;
        tokenOut = routes[len - 1].to;
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
