// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {ISwapRouter} from "../../integrations/uniswap/IUniswapV3.sol";
import {BytesLib} from "../../integrations/uniswap/BytesLib.sol";
import {IUniswapV3Adapter, UniswapV3PoolStatus} from "../../interfaces/uniswap/IUniswapV3Adapter.sol";

/// @title Uniswap V3 Router adapter
/// @notice Implements logic allowing CAs to perform swaps via Uniswap V3
contract UniswapV3Adapter is AbstractAdapter, IUniswapV3Adapter {
    using BytesLib for bytes;

    AdapterType public constant override _gearboxAdapterType = AdapterType.UNISWAP_V3_ROUTER;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

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

    /// @dev Mapping from (token0, token1, fee) to whether the pool can be traded through the adapter
    mapping(address => mapping(address => mapping(uint24 => bool))) internal _poolStatus;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _router Uniswap V3 Router address
    constructor(address _creditManager, address _router)
        AbstractAdapter(_creditManager, _router) // U:[UNI3-1]
    {}

    /// @notice Swaps given amount of input token for output token through a single pool
    /// @param params Swap params, see `ISwapRouter.ExactInputSingleParams` for details
    /// @dev `params.recipient` is ignored since it can only be the credit account
    function exactInputSingle(ISwapRouter.ExactInputSingleParams calldata params)
        external
        override
        creditFacadeOnly // U:[UNI3-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[UNI3-3]

        ISwapRouter.ExactInputSingleParams memory paramsUpdate = params; // U:[UNI3-3]
        paramsUpdate.recipient = creditAccount; // U:[UNI3-3]

        // // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            params.tokenIn, params.tokenOut, abi.encodeCall(ISwapRouter.exactInputSingle, (paramsUpdate)), false
        ); // U:[UNI3-3]
    }

    /// @notice Swaps all balance of input token for output token through a single pool, except the specified amount
    /// @param params Swap params, see `ExactDiffInputSingleParams` for details
    function exactDiffInputSingle(ExactDiffInputSingleParams calldata params)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // F: [AUV3-1]

        (tokensToEnable, tokensToDisable) = _exactDiffInputSingle(
            params.tokenIn,
            params.tokenOut,
            params.fee,
            creditAccount,
            params.deadline,
            params.leftoverAmount,
            params.rateMinRAY,
            params.sqrtPriceLimitX96
        );
    }

    /// @dev Internal implementation for `exactDiffInputSingle`
    function _exactDiffInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        address creditAccount,
        uint256 deadline,
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        uint160 sqrtPriceLimitX96
    ) internal returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        uint256 amount = IERC20(tokenIn).balanceOf(creditAccount);
        if (amount <= leftoverAmount) return (0, 0);
        unchecked {
            amount -= leftoverAmount;
        }

        ISwapRouter.ExactInputSingleParams memory paramsUpdate = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: creditAccount,
            deadline: deadline,
            amountIn: amount,
            amountOutMinimum: (amount * rateMinRAY) / RAY,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            tokenIn, tokenOut, abi.encodeCall(ISwapRouter.exactInputSingle, (paramsUpdate)), leftoverAmount <= 1
        );
    }

    /// @notice Swaps given amount of input token for output token through multiple pools
    /// @param params Swap params, see `ISwapRouter.ExactInputParams` for details
    /// @dev `params.recipient` is ignored since it can only be the credit account
    /// @dev `params.path` must have at most 3 hops through registered connector tokens
    function exactInput(ISwapRouter.ExactInputParams calldata params)
        external
        override
        creditFacadeOnly // U:[UNI3-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[UNI3-5]

        (bool valid, address tokenIn, address tokenOut) = _validatePath(params.path);
        if (!valid) revert InvalidPathException(); // U:[UNI3-5]

        ISwapRouter.ExactInputParams memory paramsUpdate = params; // U:[UNI3-5]
        paramsUpdate.recipient = creditAccount; // U:[UNI3-5]

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) =
            _executeSwapSafeApprove(tokenIn, tokenOut, abi.encodeCall(ISwapRouter.exactInput, (paramsUpdate)), false); // U:[UNI3-5]
    }

    /// @notice Swaps all balance of input token for output token through multiple pools, except the specified amount
    /// @param params Swap params, see `ExactDiffInputParams` for details
    /// @dev `params.path` must have at most 3 hops through registered connector tokens
    function exactDiffInput(ExactDiffInputParams calldata params)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();

        (tokensToEnable, tokensToDisable) =
            _exactDiffInput(creditAccount, params.path, params.deadline, params.leftoverAmount, params.rateMinRAY);
    }

    /// @dev Internal implementation for `exactDiffInput`.
    function _exactDiffInput(
        address creditAccount,
        bytes memory path,
        uint256 deadline,
        uint256 leftoverAmount,
        uint256 rateMinRAY
    ) internal returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        (bool valid, address tokenIn, address tokenOut) = _validatePath(path);
        if (!valid) revert InvalidPathException();

        uint256 amount = IERC20(tokenIn).balanceOf(creditAccount);
        if (amount <= leftoverAmount) return (0, 0);

        unchecked {
            amount -= leftoverAmount;
        }
        ISwapRouter.ExactInputParams memory paramsUpdate = ISwapRouter.ExactInputParams({
            path: path,
            recipient: creditAccount,
            deadline: deadline,
            amountIn: amount,
            amountOutMinimum: (amount * rateMinRAY) / RAY
        });

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            tokenIn, tokenOut, abi.encodeCall(ISwapRouter.exactInput, (paramsUpdate)), leftoverAmount <= 1
        );
    }

    /// @notice Swaps input token for given amount of output token through a single pool
    /// @param params Swap params, see `ISwapRouter.ExactOutputSingleParams` for details
    /// @dev `params.recipient` is ignored since it can only be the credit account
    function exactOutputSingle(ISwapRouter.ExactOutputSingleParams calldata params)
        external
        override
        creditFacadeOnly // U:[UNI3-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[UNI3-7]

        ISwapRouter.ExactOutputSingleParams memory paramsUpdate = params; // U:[UNI3-7]
        paramsUpdate.recipient = creditAccount; // U:[UNI3-7]

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            params.tokenIn, params.tokenOut, abi.encodeCall(ISwapRouter.exactOutputSingle, (paramsUpdate)), false
        ); // U:[UNI3-7]
    }

    /// @notice Swaps input token for given amount of output token through multiple pools
    /// @param params Swap params, see `ISwapRouter.ExactOutputParams` for details
    /// @dev `params.recipient` is ignored since it can only be the credit account
    /// @dev `params.path` must have at most 3 hops through registered connector tokens
    function exactOutput(ISwapRouter.ExactOutputParams calldata params)
        external
        override
        creditFacadeOnly // U:[UNI3-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[UNI3-8]

        (bool valid, address tokenOut, address tokenIn) = _validatePath(params.path);
        if (!valid) revert InvalidPathException(); // U:[UNI3-8]

        ISwapRouter.ExactOutputParams memory paramsUpdate = params; // U:[UNI3-8]
        paramsUpdate.recipient = creditAccount; // U:[UNI3-8]

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) =
            _executeSwapSafeApprove(tokenIn, tokenOut, abi.encodeCall(ISwapRouter.exactOutput, (paramsUpdate)), false); // U:[UNI3-8]
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Returns whether the (token0, token1, fee) pool is allowed to be traded through the adapter
    function isPoolAllowed(address token0, address token1, uint24 fee) public view override returns (bool) {
        (token0, token1) = _sortTokens(token0, token1);
        return _poolStatus[token0][token1][fee];
    }

    /// @notice Sets status for a batch of pools
    /// @param pools Array of `UniswapV3PoolStatus` objects
    function setPoolStatusBatch(UniswapV3PoolStatus[] calldata pools)
        external
        override
        configuratorOnly // U:[UNI3-9]
    {
        uint256 len = pools.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                (address token0, address token1) = _sortTokens(pools[i].token0, pools[i].token1);
                _poolStatus[token0][token1][pools[i].fee] = pools[i].allowed; // U:[UNI3-9]
                emit SetPoolStatus(token0, token1, pools[i].fee, pools[i].allowed); // U:[UNI3-9]
            }
        }
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Performs sanity checks on a swap path, if path is valid also returns input and output tokens
    ///      - Path length must be no more than 4 (i.e., at most 3 hops)
    ///      - Each swap must be through an allowed pool
    function _validatePath(bytes memory path) internal view returns (bool valid, address tokenIn, address tokenOut) {
        uint256 len = path.length;
        if (len != PATH_2_LENGTH && len != PATH_3_LENGTH && len != PATH_4_LENGTH) return (false, tokenIn, tokenOut); // U:[UNI3-10]

        tokenIn = path.toAddress(0); // U:[UNI3-10]
        uint24 fee = path.toUint24(ADDR_SIZE);
        tokenOut = path.toAddress(NEXT_OFFSET); // U:[UNI3-10]
        valid = isPoolAllowed(tokenIn, tokenOut, fee); // U:[UNI3-10]

        if (valid && len > PATH_2_LENGTH) {
            address tokenMid = tokenOut;
            fee = path.toUint24(NEXT_OFFSET + ADDR_SIZE);
            tokenOut = path.toAddress(2 * NEXT_OFFSET); // U:[UNI3-10]
            valid = isPoolAllowed(tokenMid, tokenOut, fee); // U:[UNI3-10]

            if (valid && len > PATH_3_LENGTH) {
                tokenMid = tokenOut;
                fee = path.toUint24(2 * NEXT_OFFSET + ADDR_SIZE);
                tokenOut = path.toAddress(3 * NEXT_OFFSET); // U:[UNI3-10]
                valid = isPoolAllowed(tokenMid, tokenOut, fee); // U:[UNI3-10]
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
