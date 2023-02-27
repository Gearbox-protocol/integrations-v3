// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AdapterType} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";
import {AbstractAdapter} from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";
import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {ISwapRouter} from "../../integrations/uniswap/IUniswapV3.sol";
import {Path} from "../../integrations/uniswap/Path.sol";
import {IUniswapV3Adapter} from "../../interfaces/uniswap/IUniswapV3Adapter.sol";
import {UniswapConnectorChecker} from "./UniswapConnectorChecker.sol";

/// @dev The length of the bytes encoded address
uint256 constant ADDR_SIZE = 20;

/// @dev The length of the uint24 encoded address
uint256 constant FEE_SIZE = 3;

/// @dev Minimal path length in bytes
uint256 constant MIN_PATH_LENGTH = 2 * ADDR_SIZE + FEE_SIZE;

/// @dev Number of bytes in path per single token
uint256 constant ADDR_PLUS_FEE_LENGTH = ADDR_SIZE + FEE_SIZE;

/// @dev Maximal allowed path length in bytes (3 hops)
uint256 constant MAX_PATH_LENGTH = 4 * ADDR_SIZE + 3 * FEE_SIZE;

/// @title Uniswap V3 Router adapter
contract UniswapV3Adapter is AbstractAdapter, UniswapConnectorChecker, IUniswapV3Adapter {
    using Path for bytes;

    AdapterType public constant _gearboxAdapterType = AdapterType.UNISWAP_V3_ROUTER;
    uint16 public constant _gearboxAdapterVersion = 3;

    /// @dev Constructor
    /// @param _creditManager Address Credit manager
    /// @param _router Address of ISwapRouter
    constructor(address _creditManager, address _router, address[] memory _connectorTokensInit)
        AbstractAdapter(_creditManager, _router)
        UniswapConnectorChecker(_connectorTokensInit)
    {}

    /// @notice Sends an order to swap `amountIn` of one token for as much as possible of another token
    /// - Makes a max allowance fast check call, replacing the recipient with the Credit Account
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    function exactInputSingle(ISwapRouter.ExactInputSingleParams calldata params) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AUV3-1]

        ISwapRouter.ExactInputSingleParams memory paramsUpdate = params; // F:[AUV3-2,10]
        paramsUpdate.recipient = creditAccount; // F:[AUV3-2,10]

        _executeSwapMaxApprove(
            creditAccount,
            params.tokenIn,
            params.tokenOut,
            abi.encodeCall(ISwapRouter.exactInputSingle, (paramsUpdate)),
            false
        ); // F:[AUV2-2,10]
    }

    /// @notice Sends an order to swap the entire balance of one token for as much as possible of another token
    /// - Fills the `ExactInputSingleParams` struct
    /// - Makes a max allowance fast check call, passing the new struct as params
    /// @param params The parameters necessary for the swap, encoded as `ExactAllInputSingleParams` in calldata
    /// `ExactAllInputSingleParams` has the following fields:
    /// - tokenIn - same as normal params
    /// - tokenOut - same as normal params
    /// - fee - same as normal params
    /// - deadline - same as normal params
    /// - rateMinRAY - Minimal exchange rate between the input and the output tokens
    /// - sqrtPriceLimitX96 - same as normal params
    function exactAllInputSingle(ExactAllInputSingleParams calldata params) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AUV3-1]

        uint256 balanceInBefore = IERC20(params.tokenIn).balanceOf(creditAccount); // F:[AUV3-3]

        // We keep 1 on tokenIn balance for gas efficiency
        if (balanceInBefore > 1) {
            unchecked {
                balanceInBefore--;
            }

            ISwapRouter.ExactInputSingleParams memory paramsUpdate = ISwapRouter.ExactInputSingleParams({
                tokenIn: params.tokenIn,
                tokenOut: params.tokenOut,
                fee: params.fee,
                recipient: creditAccount,
                deadline: params.deadline,
                amountIn: balanceInBefore,
                amountOutMinimum: (balanceInBefore * params.rateMinRAY) / RAY,
                sqrtPriceLimitX96: params.sqrtPriceLimitX96
            }); // F:[AUV3-3]

            _executeSwapMaxApprove(
                creditAccount,
                params.tokenIn,
                params.tokenOut,
                abi.encodeCall(ISwapRouter.exactInputSingle, (paramsUpdate)),
                true
            ); // F:[AUV3-3]
        }
    }

    /// @notice Sends an order to swap `amountIn` of one token for as much as possible of another along the specified path
    /// - Makes a max allowance fast check call, replacing the recipient with the Credit Account
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    function exactInput(ISwapRouter.ExactInputParams calldata params) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AUV3-1]

        (bool valid, address tokenIn, address tokenOut) = _parseUniV3Path(params.path);
        if (!valid) {
            revert InvalidPathException(); // F:[AUV3-9]
        }

        ISwapRouter.ExactInputParams memory paramsUpdate = params; // F:[AUV3-4]
        paramsUpdate.recipient = creditAccount; // F:[AUV3-4]

        _executeSwapMaxApprove(
            creditAccount, tokenIn, tokenOut, abi.encodeCall(ISwapRouter.exactInput, (paramsUpdate)), false
        ); // F:[AUV3-4]
    }

    /// @notice Swaps the entire balance of one token for as much as possible of another along the specified path
    /// - Fills the `ExactAllInputParams` struct
    /// - Makes a max allowance fast check call, passing the new struct as `params`
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactAllInputParams` in calldata
    /// `ExactAllInputParams` has the following fields:
    /// - path - same as normal params
    /// - deadline - same as normal params
    /// - rateMinRAY - minimal exchange rate between the input and the output tokens
    function exactAllInput(ExactAllInputParams calldata params) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AUV3-1]

        (bool valid, address tokenIn, address tokenOut) = _parseUniV3Path(params.path);
        if (!valid) {
            revert InvalidPathException(); // F:[AUV3-9]
        }

        uint256 balanceInBefore = IERC20(tokenIn).balanceOf(creditAccount); // F:[AUV3-5]

        // We keep 1 on tokenIn balance for gas efficiency
        if (balanceInBefore > 1) {
            unchecked {
                balanceInBefore--;
            }
            ISwapRouter.ExactInputParams memory paramsUpdate = ISwapRouter.ExactInputParams({
                path: params.path,
                recipient: creditAccount,
                deadline: params.deadline,
                amountIn: balanceInBefore,
                amountOutMinimum: (balanceInBefore * params.rateMinRAY) / RAY
            }); // F:[AUV3-5]

            _executeSwapMaxApprove(
                creditAccount, tokenIn, tokenOut, abi.encodeCall(ISwapRouter.exactInput, (paramsUpdate)), true
            ); // F:[AUV3-5]
        }
    }

    /// @notice Sends an order to swap as little as possible of one token for `amountOut` of another token
    /// - Makes a max allowance fast check call, replacing the recipient with the Credit Account
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    function exactOutputSingle(ISwapRouter.ExactOutputSingleParams calldata params)
        external
        override
        creditFacadeOnly
    {
        address creditAccount = _creditAccount(); // F:[AUV3-1]

        ISwapRouter.ExactOutputSingleParams memory paramsUpdate = params; // F:[AUV3-6]
        paramsUpdate.recipient = creditAccount; // F:[AUV3-6]

        _executeSwapMaxApprove(
            creditAccount,
            paramsUpdate.tokenIn,
            paramsUpdate.tokenOut,
            abi.encodeCall(ISwapRouter.exactOutputSingle, (paramsUpdate)),
            false
        ); // F:[AUV3-6]
    }

    /// @notice Sends an order to swap as little as possible of one token for
    /// `amountOut` of another along the specified path (reversed)
    /// - Makes a max allowance fast check call, replacing the recipient with the Credit Account
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    function exactOutput(ISwapRouter.ExactOutputParams calldata params) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AUV3-1]

        (bool valid, address tokenOut, address tokenIn) = _parseUniV3Path(params.path);
        if (!valid) {
            revert InvalidPathException(); // F:[AUV3-9]
        }

        ISwapRouter.ExactOutputParams memory paramsUpdate = params; // F:[AUV3-7]
        paramsUpdate.recipient = creditAccount; // F:[AUV3-7]

        _executeSwapMaxApprove(
            creditAccount, tokenIn, tokenOut, abi.encodeCall(ISwapRouter.exactOutput, (paramsUpdate)), false
        ); // F:[AUV3-7]
    }

    /// @dev Performs sanity checks on a Uniswap V3 path and returns the input and output tokens
    /// @param path Path to check
    /// @notice Sanity checks include path length not being more than 3 hops and intermediary tokens
    ///         being allowed as connectors
    function _parseUniV3Path(bytes memory path) internal view returns (bool valid, address tokenIn, address tokenOut) {
        valid = true;

        if (path.length < MIN_PATH_LENGTH || path.length > MAX_PATH_LENGTH) {
            valid = false;
        }

        (tokenIn,,) = path.decodeFirstPool();

        while (path.hasMultiplePools()) {
            (, address midToken,) = path.decodeFirstPool();

            if (!isConnector(midToken)) {
                valid = false;
            }

            path = path.skipToken();
        }

        (, tokenOut,) = path.decodeFirstPool();
    }
}
