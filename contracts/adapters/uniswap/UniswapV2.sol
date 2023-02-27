// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AdapterType} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";
import {AbstractAdapter} from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";
import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {IUniswapV2Router02} from "../../integrations/uniswap/IUniswapV2Router02.sol";
import {IUniswapV2Adapter} from "../../interfaces/uniswap/IUniswapV2Adapter.sol";
import {UniswapConnectorChecker} from "./UniswapConnectorChecker.sol";

/// @title Uniswap V2 Router adapter
contract UniswapV2Adapter is AbstractAdapter, UniswapConnectorChecker, IUniswapV2Adapter {
    AdapterType public constant _gearboxAdapterType = AdapterType.UNISWAP_V2_ROUTER;
    uint16 public constant _gearboxAdapterVersion = 3;

    /// @dev Constructor
    /// @param _creditManager Address Credit manager
    /// @param _router Address of IUniswapV2Router02
    constructor(address _creditManager, address _router, address[] memory _connectorTokensInit)
        AbstractAdapter(_creditManager, _router)
        UniswapConnectorChecker(_connectorTokensInit)
    {}

    /**
     * @dev Sends an order to swap tokens to exact tokens using a Uniswap-compatible protocol
     * - Makes a max allowance fast check call to target, replacing the `to` parameter with the CA address
     * @param amountOut The amount of output tokens to receive.
     * @param amountInMax The maximum amount of input tokens that can be required before the transaction reverts.
     * @param path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of
     *        addresses must exist and have liquidity.
     * @param deadline Unix timestamp after which the transaction will revert.
     * for more information, see: https://uniswap.org/docs/v2/smart-contracts/router02/
     * @notice `to` is ignored, since it is forbidden to transfer funds from a CA
     * @notice Fast check parameters:
     * Input token: First token in the path
     * Output token: Last token in the path
     * Input token is allowed, since the target does a transferFrom for the input token
     * The input token does not need to be disabled, because this does not spend the entire
     * balance, generally
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address,
        uint256 deadline
    ) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AUV2-1]

        (bool valid, address tokenIn, address tokenOut) = _parseUniV2Path(path); // F:[AUV2-2, UPC-3]
        if (!valid) {
            revert InvalidPathException(); // F:[AUV2-5]
        }

        _executeSwapMaxApprove(
            creditAccount,
            tokenIn,
            tokenOut,
            abi.encodeCall(
                IUniswapV2Router02.swapTokensForExactTokens, (amountOut, amountInMax, path, creditAccount, deadline)
            ),
            false
        ); // F:[AUV2-2]
    }

    /**
     * @dev Sends an order to swap an exact amount of token to another token using a Uniswap-compatible protocol
     * - Makes a max allowance fast check call to target, replacing the `to` parameter with the CA address
     * @param amountIn The amount of input tokens to send.
     * @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
     * @param path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of
     *        addresses must exist and have liquidity.
     * @param deadline Unix timestamp after which the transaction will revert.
     * for more information, see: https://uniswap.org/docs/v2/smart-contracts/router02/
     * @notice `to` is ignored, since it is forbidden to transfer funds from a CA
     * @notice Fast check parameters:
     * Input token: First token in the path
     * Output token: Last token in the path
     * Input token is allowed, since the target does a transferFrom for the input token
     * The input token does not need to be disabled, because this does not spend the entire
     * balance, generally
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address,
        uint256 deadline
    ) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AUV2-1]

        (bool valid, address tokenIn, address tokenOut) = _parseUniV2Path(path); // F:[AUV2-3, UPC-3]
        if (!valid) {
            revert InvalidPathException(); // F:[AUV2-5]
        }

        _executeSwapMaxApprove(
            creditAccount,
            tokenIn,
            tokenOut,
            abi.encodeCall(
                IUniswapV2Router02.swapExactTokensForTokens, (amountIn, amountOutMin, path, creditAccount, deadline)
            ),
            false
        ); // F:[AUV2-3]
    }

    /**
     * @dev Sends an order to swap the entire token balance to another token using a Uniswap-compatible protocol
     * - Makes a max allowance fast check call to target, replacing the `to` parameter with the CA address
     * @param rateMinRAY The minimal exchange rate between the input and the output tokens.
     * @param path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of
     *        addresses must exist and have liquidity.
     * @param deadline Unix timestamp after which the transaction will revert.
     * for more information, see: https://uniswap.org/docs/v2/smart-contracts/router02/
     * @notice Under the hood, calls swapExactTokensForTokens, passing balance minus 1 as the amount
     * @notice Fast check parameters:
     * Input token: First token in the path
     * Output token: Last token in the path
     * Input token is allowed, since the target does a transferFrom for the input token
     * The input token does need to be disabled, because this spends the entire balance
     */
    function swapAllTokensForTokens(uint256 rateMinRAY, address[] calldata path, uint256 deadline)
        external
        override
        creditFacadeOnly
    {
        address creditAccount = _creditAccount(); // F:[AUV2-1]

        address tokenIn;
        address tokenOut;
        {
            bool valid;
            (valid, tokenIn, tokenOut) = _parseUniV2Path(path); // F:[AUV2-4, UPC-3]

            if (!valid) {
                revert InvalidPathException(); // F:[AUV2-5]
            }
        }

        uint256 balanceInBefore = IERC20(tokenIn).balanceOf(creditAccount); // F:[AUV2-4]

        if (balanceInBefore > 1) {
            unchecked {
                balanceInBefore--;
            }

            _executeSwapMaxApprove(
                creditAccount,
                tokenIn,
                tokenOut,
                abi.encodeCall(
                    IUniswapV2Router02.swapExactTokensForTokens,
                    (balanceInBefore, (balanceInBefore * rateMinRAY) / RAY, path, creditAccount, deadline)
                ),
                true
            ); // F:[AUV2-4]
        }
    }

    /// @dev Performs sanity checks on a Uniswap V2 path and returns the input and output tokens
    /// @param path Path to check
    /// @notice Sanity checks include path length not being more than 4 (more than 3 hops) and intermediary tokens
    ///         being allowed as connectors
    function _parseUniV2Path(address[] memory path)
        internal
        view
        returns (bool valid, address tokenIn, address tokenOut)
    {
        valid = true;
        tokenIn = path[0];
        tokenOut = path[path.length - 1];

        uint256 len = path.length;

        if (len > 4) {
            valid = false;
        }

        for (uint256 i = 1; i < len - 1;) {
            if (!isConnector(path[i])) {
                valid = false;
            }

            unchecked {
                ++i;
            }
        }
    }
}
