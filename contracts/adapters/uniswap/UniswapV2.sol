// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {IUniswapV2Router02} from "../../integrations/uniswap/IUniswapV2Router02.sol";
import {IUniswapV2Adapter, UniswapV2PairStatus} from "../../interfaces/uniswap/IUniswapV2Adapter.sol";

/// @title Uniswap V2 Router adapter interface
/// @notice Implements logic allowing CAs to perform swaps via Uniswap V2 and its forks
contract UniswapV2Adapter is AbstractAdapter, IUniswapV2Adapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.UNISWAP_V2_ROUTER;
    uint16 public constant override _gearboxAdapterVersion = 3;

    /// @dev Mapping from (token0, token1) to whether the pair can be traded through the adapter
    mapping(address => mapping(address => bool)) internal _pairStatus;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _router Uniswap V2 Router address
    constructor(address _creditManager, address _router) AbstractAdapter(_creditManager, _router) {}

    /// @notice Swap input token for given amount of output token
    /// @param amountOut Amount of output token to receive
    /// @param amountInMax Maximum amount of input token to spend
    /// @param path Array of token addresses representing swap path, which must have at most 3 hops
    ///        through registered connector tokens
    /// @param deadline Maximum timestamp until which the transaction is valid
    /// @dev Parameter `to` is ignored since swap recipient can only be the credit account
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address,
        uint256 deadline
    ) external override creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        address creditAccount = _creditAccount(); // F: [AUV2-1]

        (bool valid, address tokenIn, address tokenOut) = _validatePath(path); // F: [AUV2-2]
        if (!valid) revert InvalidPathException(); // F: [AUV2-5]

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            tokenIn,
            tokenOut,
            abi.encodeCall(
                IUniswapV2Router02.swapTokensForExactTokens, (amountOut, amountInMax, path, creditAccount, deadline)
            ),
            false
        ); // F: [AUV2-2]
    }

    /// @notice Swap given amount of input token to output token
    /// @param amountIn Amount of input token to spend
    /// @param amountOutMin Minumum amount of output token to receive
    /// @param path Array of token addresses representing swap path, which must have at most 3 hops
    ///        through registered connector tokens
    /// @param deadline Maximum timestamp until which the transaction is valid
    /// @dev Parameter `to` is ignored since swap recipient can only be the credit account
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address,
        uint256 deadline
    ) external override creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        address creditAccount = _creditAccount(); // F: [AUV2-1]

        (bool valid, address tokenIn, address tokenOut) = _validatePath(path); // F: [AUV2-3]
        if (!valid) revert InvalidPathException(); // F: [AUV2-5]

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            tokenIn,
            tokenOut,
            abi.encodeCall(
                IUniswapV2Router02.swapExactTokensForTokens, (amountIn, amountOutMin, path, creditAccount, deadline)
            ),
            false
        ); // F: [AUV2-3]
    }

    /// @notice Swap the entire balance of input token to output token, disables input token
    /// @param rateMinRAY Minimum exchange rate between input and output tokens, scaled by 1e27
    /// @param path Array of token addresses representing swap path, which must have at most 3 hops
    ///        through registered connector tokens
    /// @param deadline Maximum timestamp until which the transaction is valid
    function swapAllTokensForTokens(uint256 rateMinRAY, address[] calldata path, uint256 deadline)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // F: [AUV2-1]

        (bool valid, address tokenIn, address tokenOut) = _validatePath(path); // F: [AUV2-4]
        if (!valid) revert InvalidPathException(); // F: [AUV2-5]

        uint256 balance = IERC20(tokenIn).balanceOf(creditAccount); // F: [AUV2-4]
        if (balance <= 1) return (0, 0);

        unchecked {
            balance--;
        }

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            tokenIn,
            tokenOut,
            abi.encodeCall(
                IUniswapV2Router02.swapExactTokensForTokens,
                (balance, (balance * rateMinRAY) / RAY, path, creditAccount, deadline)
            ),
            true
        ); // F: [AUV2-4]
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Returns whether the (token0, token1) pair is allowed to be traded through the adapter
    function isPairAllowed(address token0, address token1) public view override returns (bool) {
        (token0, token1) = _sortTokens(token0, token1);
        return _pairStatus[token0][token1];
    }

    /// @notice Sets status for a batch of pairs
    /// @param pairs Array of `UniswapV2PairStatus` objects
    function setPairStatusBatch(UniswapV2PairStatus[] calldata pairs) external override configuratorOnly {
        uint256 len = pairs.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                (address token0, address token1) = _sortTokens(pairs[i].token0, pairs[i].token1);
                _pairStatus[token0][token1] = pairs[i].allowed;
                emit SetPairStatus(token0, token1, pairs[i].allowed);
            }
        }
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Performs sanity check on a swap path, if path is valid also returns input and output tokens
    ///      - Path length must be no more than 4 (i.e., at most 3 hops)
    ///      - Each swap must be through an allowed pair
    function _validatePath(address[] memory path)
        internal
        view
        returns (bool valid, address tokenIn, address tokenOut)
    {
        uint256 len = path.length;
        if (len < 2 || len > 4) return (false, tokenIn, tokenOut);

        tokenIn = path[0];
        tokenOut = path[len - 1];
        valid = isPairAllowed(path[0], path[1]);
        if (valid && len > 2) {
            valid = isPairAllowed(path[1], path[2]);
            if (valid && len > 3) valid = isPairAllowed(path[2], path[3]);
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
