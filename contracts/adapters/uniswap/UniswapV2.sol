// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk/contracts/AdapterType.sol";

import {IUniswapV2Router02} from "../../integrations/uniswap/IUniswapV2Router02.sol";
import {IUniswapV2Adapter, UniswapPairStatus} from "../../interfaces/uniswap/IUniswapV2Adapter.sol";

/// @title Uniswap V2 Router adapter interface
/// @notice Implements logic allowing CAs to perform swaps via Uniswap V2 and its forks
contract UniswapV2Adapter is AbstractAdapter, IUniswapV2Adapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.UNISWAP_V2_ROUTER;
    uint16 public constant override _gearboxAdapterVersion = 3;

    /// @notice Mapping from (token0, token1) to whether the pair can be traded through the adapter
    /// @dev Tokens are sorted alphanumerically by address
    mapping(address => mapping(address => bool)) internal allowedPair;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _router Uniswap V2 Router address
    constructor(address _creditManager, address _router) AbstractAdapter(_creditManager, _router) {}

    /// @inheritdoc IUniswapV2Adapter
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address,
        uint256 deadline
    ) external override creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        address creditAccount = _creditAccount(); // F: [AUV2-1]

        (bool valid, address tokenIn, address tokenOut) = _parseUniV2Path(path); // F: [AUV2-2]
        if (!valid) {
            revert InvalidPathException(); // F: [AUV2-5]
        }

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

    /// @inheritdoc IUniswapV2Adapter
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address,
        uint256 deadline
    ) external override creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        address creditAccount = _creditAccount(); // F: [AUV2-1]

        (bool valid, address tokenIn, address tokenOut) = _parseUniV2Path(path); // F: [AUV2-3]
        if (!valid) {
            revert InvalidPathException(); // F: [AUV2-5]
        }

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

    /// @inheritdoc IUniswapV2Adapter
    function swapAllTokensForTokens(uint256 rateMinRAY, address[] calldata path, uint256 deadline)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // F: [AUV2-1]

        (bool valid, address tokenIn, address tokenOut) = _parseUniV2Path(path); // F: [AUV2-4]
        if (!valid) {
            revert InvalidPathException(); // F: [AUV2-5]
        }

        uint256 balanceInBefore = IERC20(tokenIn).balanceOf(creditAccount); // F: [AUV2-4]
        if (balanceInBefore <= 1) return (0, 0);

        unchecked {
            balanceInBefore--;
        }

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            tokenIn,
            tokenOut,
            abi.encodeCall(
                IUniswapV2Router02.swapExactTokensForTokens,
                (balanceInBefore, (balanceInBefore * rateMinRAY) / RAY, path, creditAccount, deadline)
            ),
            true
        ); // F: [AUV2-4]
    }

    /// @dev Sort two token addresses alphanumerically
    function _sortTokens(address token0, address token1) internal pure returns (address, address) {
        if (uint160(token0) < uint160(token1)) {
            return (token0, token1);
        } else {
            return (token1, token0);
        }
    }

    /// @dev Performs sanity check on a swap path, returns input and output tokens
    ///      - Path length must be no more than 4 (i.e., at most 3 hops)
    ///       - Each swap must be through an allowed pair
    function _parseUniV2Path(address[] memory path)
        internal
        view
        returns (bool valid, address tokenIn, address tokenOut)
    {
        uint256 len = path.length;

        tokenIn = path[0];
        tokenOut = path[len - 1];

        valid = isPairAllowed(path[0], path[1]);

        if (valid && len > 2) {
            valid = isPairAllowed(path[1], path[2]);
        }

        if (valid && len > 3) {
            valid = isPairAllowed(path[2], path[3]);
        }

        if (len > 4) {
            valid = false;
        }
    }

    /// @notice Returns whether the (token0, token1) is allowed to be traded through the adapter
    function isPairAllowed(address token0, address token1) public view returns (bool) {
        (token0, token1) = _sortTokens(token0, token1);
        return allowedPair[token0][token1];
    }

    /// @notice Changes the whitelisted status for a batch of pairs
    /// @param pairs Array of UniswaPairStatus objects:
    ///              * token0 - First token in a pair
    ///              * token1 - Second token in a pair
    ///              * allowed - Status to set
    function setPairBatchAllowanceStatus(UniswapPairStatus[] calldata pairs) external configuratorOnly {
        uint256 len = pairs.length;

        for (uint256 i = 0; i < len; ++i) {
            (address token0, address token1) = _sortTokens(pairs[i].token0, pairs[i].token1);
            allowedPair[token0][token1] = pairs[i].allowed;
        }
    }
}
