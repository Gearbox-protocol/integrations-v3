// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "../../interfaces/IAdapter.sol";

import {ISwapRouter} from "../../integrations/uniswap/IUniswapV3.sol";
import {BytesLib} from "../../integrations/uniswap/BytesLib.sol";
import {IUniswapV3Adapter, UniswapV3PoolStatus} from "../../interfaces/uniswap/IUniswapV3Adapter.sol";

/// @title Uniswap V3 Router adapter interface
/// @notice Implements logic allowing CAs to perform swaps via Uniswap V3
contract UniswapV3Adapter is AbstractAdapter, IUniswapV3Adapter {
    using BytesLib for bytes;

    /// @dev The length of the bytes encoded address
    uint256 private constant ADDR_SIZE = 20;

    /// @dev The length of the uint24 encoded address
    uint256 private constant FEE_SIZE = 3;

    /// @dev The offset of a single token address and pool fee
    uint256 private constant NEXT_OFFSET = ADDR_SIZE + FEE_SIZE;

    /// @dev The length of the path with 1 hop
    uint256 private constant PATH_2_LENGTH = 2 * ADDR_SIZE + FEE_SIZE;

    /// @dev The length of the path with 2 hops
    uint256 private constant PATH_3_LENGTH = 3 * ADDR_SIZE + 2 * FEE_SIZE;

    /// @dev The length of the path with 3 hops
    uint256 private constant PATH_4_LENGTH = 4 * ADDR_SIZE + 3 * FEE_SIZE;

    AdapterType public constant override _gearboxAdapterType = AdapterType.UNISWAP_V3_ROUTER;
    uint16 public constant override _gearboxAdapterVersion = 3;

    /// @notice Mapping from (token0, token1, fee) to whether the corresponding pool can be traded through the adapter
    /// @dev Tokens in each pair are sorted alphanumerically by address
    mapping(address => mapping(address => mapping(uint24 => bool))) internal allowedPool;

    /// @notice Constructor
    /// @param _CreditManagerV3 Credit manager address
    /// @param _router Uniswap V3 Router address
    constructor(address _CreditManagerV3, address _router) AbstractAdapter(_CreditManagerV3, _router) {}

    /// @inheritdoc IUniswapV3Adapter
    function exactInputSingle(ISwapRouter.ExactInputSingleParams calldata params)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // F: [AUV3-1]

        ISwapRouter.ExactInputSingleParams memory paramsUpdate = params; // F: [AUV3-2]
        paramsUpdate.recipient = creditAccount; // F: [AUV3-2]

        // // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            params.tokenIn, params.tokenOut, abi.encodeCall(ISwapRouter.exactInputSingle, (paramsUpdate)), false
        ); // F: [AUV3-2]
    }

    /// @inheritdoc IUniswapV3Adapter
    function exactAllInputSingle(ExactAllInputSingleParams calldata params)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // F: [AUV3-1]

        uint256 balanceInBefore = IERC20(params.tokenIn).balanceOf(creditAccount); // F: [AUV3-3]
        if (balanceInBefore <= 1) return (0, 0);

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
        }); // F: [AUV3-3]

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            params.tokenIn, params.tokenOut, abi.encodeCall(ISwapRouter.exactInputSingle, (paramsUpdate)), true
        ); // F: [AUV3-3]
    }

    /// @inheritdoc IUniswapV3Adapter
    function exactInput(ISwapRouter.ExactInputParams calldata params)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // F: [AUV3-1]

        (bool valid, address tokenIn, address tokenOut) = _parseUniV3Path(params.path);
        if (!valid) {
            revert InvalidPathException(); // F: [AUV3-9]
        }

        ISwapRouter.ExactInputParams memory paramsUpdate = params; // F: [AUV3-4]
        paramsUpdate.recipient = creditAccount; // F: [AUV3-4]

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) =
            _executeSwapSafeApprove(tokenIn, tokenOut, abi.encodeCall(ISwapRouter.exactInput, (paramsUpdate)), false); // F: [AUV3-4]
    }

    /// @inheritdoc IUniswapV3Adapter
    function exactAllInput(ExactAllInputParams calldata params)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // F: [AUV3-1]

        (bool valid, address tokenIn, address tokenOut) = _parseUniV3Path(params.path);
        if (!valid) {
            revert InvalidPathException(); // F: [AUV3-9]
        }

        uint256 balanceInBefore = IERC20(tokenIn).balanceOf(creditAccount); // F: [AUV3-5]
        if (balanceInBefore <= 1) return (0, 0);

        unchecked {
            balanceInBefore--;
        }
        ISwapRouter.ExactInputParams memory paramsUpdate = ISwapRouter.ExactInputParams({
            path: params.path,
            recipient: creditAccount,
            deadline: params.deadline,
            amountIn: balanceInBefore,
            amountOutMinimum: (balanceInBefore * params.rateMinRAY) / RAY
        }); // F: [AUV3-5]

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) =
            _executeSwapSafeApprove(tokenIn, tokenOut, abi.encodeCall(ISwapRouter.exactInput, (paramsUpdate)), true); // F: [AUV3-5]
    }

    /// @inheritdoc IUniswapV3Adapter
    function exactOutputSingle(ISwapRouter.ExactOutputSingleParams calldata params)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // F: [AUV3-1]

        ISwapRouter.ExactOutputSingleParams memory paramsUpdate = params; // F: [AUV3-6]
        paramsUpdate.recipient = creditAccount; // F: [AUV3-6]

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            params.tokenIn, params.tokenOut, abi.encodeCall(ISwapRouter.exactOutputSingle, (paramsUpdate)), false
        ); // F: [AUV3-6]
    }

    /// @inheritdoc IUniswapV3Adapter
    function exactOutput(ISwapRouter.ExactOutputParams calldata params)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // F: [AUV3-1]

        (bool valid, address tokenOut, address tokenIn) = _parseUniV3Path(params.path);
        if (!valid) {
            revert InvalidPathException(); // F: [AUV3-9]
        }

        ISwapRouter.ExactOutputParams memory paramsUpdate = params; // F: [AUV3-7]
        paramsUpdate.recipient = creditAccount; // F: [AUV3-7]

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) =
            _executeSwapSafeApprove(tokenIn, tokenOut, abi.encodeCall(ISwapRouter.exactOutput, (paramsUpdate)), false); // F: [AUV3-7]
    }

    /// @dev Performs sanity checks on a swap path, returns input and output tokens
    ///      - Path length must be no more than 4 (i.e., at most 3 hops)
    ///      - Each swap must be through an allowed pool
    function _parseUniV3Path(bytes memory path) internal view returns (bool valid, address tokenIn, address tokenOut) {
        uint256 len = path.length;

        if (len == PATH_2_LENGTH) {
            tokenIn = path.toAddress(0);
            tokenOut = path.toAddress(NEXT_OFFSET);
            uint24 fee = path.toUint24(ADDR_SIZE);

            valid = isPoolAllowed(tokenIn, tokenOut, fee);

            return (valid, tokenIn, tokenOut);
        }

        if (len == PATH_3_LENGTH) {
            tokenIn = path.toAddress(0);
            address tokenMid = path.toAddress(NEXT_OFFSET);
            tokenOut = path.toAddress(2 * NEXT_OFFSET);

            uint24 fee0 = path.toUint24(ADDR_SIZE);
            uint24 fee1 = path.toUint24(NEXT_OFFSET + ADDR_SIZE);

            valid = isPoolAllowed(tokenIn, tokenMid, fee0) && isPoolAllowed(tokenMid, tokenOut, fee1);
            return (valid, tokenIn, tokenOut);
        }

        if (len == PATH_4_LENGTH) {
            tokenIn = path.toAddress(0);
            address tokenMid0 = path.toAddress(NEXT_OFFSET);
            address tokenMid1 = path.toAddress(2 * NEXT_OFFSET);
            tokenOut = path.toAddress(3 * NEXT_OFFSET);

            uint24 fee0 = path.toUint24(ADDR_SIZE);
            uint24 fee1 = path.toUint24(NEXT_OFFSET + ADDR_SIZE);
            uint24 fee2 = path.toUint24(2 * NEXT_OFFSET + ADDR_SIZE);

            valid = isPoolAllowed(tokenIn, tokenMid0, fee0) && isPoolAllowed(tokenMid0, tokenMid1, fee1)
                && isPoolAllowed(tokenMid1, tokenOut, fee2);

            return (valid, tokenIn, tokenOut);
        }
    }

    /// @dev Sort two token addresses alphanumerically
    function _sortTokens(address token0, address token1) internal pure returns (address, address) {
        if (uint160(token0) < uint160(token1)) {
            return (token0, token1);
        } else {
            return (token1, token0);
        }
    }

    /// @notice Returns whether the (token0, token1, fee) pool is allowed to be traded through the adapter
    function isPoolAllowed(address token0, address token1, uint24 fee) public view returns (bool) {
        (token0, token1) = _sortTokens(token0, token1);
        return allowedPool[token0][token1][fee];
    }

    /// @notice Changes the whitelisted status for a batch of pairs
    /// @param pools Array of UniswaV3PoolStatus objects:
    ///              * token0 - First token in a pool
    ///              * token1 - Second token in a pool
    ///              * fee - fee of the pool
    ///              * allowed - Status to set
    function setPoolBatchAllowanceStatus(UniswapV3PoolStatus[] calldata pools) external configuratorOnly {
        uint256 len = pools.length;

        for (uint256 i = 0; i < len; ++i) {
            (address token0, address token1) = _sortTokens(pools[i].token0, pools[i].token1);
            allowedPool[token0][token1][pools[i].fee] = pools[i].allowed;
        }
    }
}
