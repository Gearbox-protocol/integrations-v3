// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {ISwapRouter} from "../../integrations/uniswap/IUniswapV3.sol";
import {BytesLib} from "../../integrations/uniswap/BytesLib.sol";
import {IUniswapV3Adapter, UniswapV3PoolStatus, UniswapV3Pool} from "../../interfaces/uniswap/IUniswapV3Adapter.sol";

/// @title Uniswap V3 Router adapter
/// @notice Implements logic allowing CAs to perform swaps via Uniswap V3
contract UniswapV3Adapter is AbstractAdapter, IUniswapV3Adapter {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using BytesLib for bytes;

    bytes32 public constant override contractType = "AD_UNISWAP_V3_ROUTER";
    uint256 public constant override version = 3_10;

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

    /// @dev Mapping from hash(token0, token1, fee) to respective tuple
    mapping(bytes32 => UniswapV3Pool) internal _hashToPool;

    /// @dev Set of hashes of (token0, token1, fee) for all supported pools
    EnumerableSet.Bytes32Set internal _supportedPoolHashes;

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
        returns (bool)
    {
        if (!isPoolAllowed(params.tokenIn, params.tokenOut, params.fee)) revert InvalidPathException();

        address creditAccount = _creditAccount(); // U:[UNI3-3]

        ISwapRouter.ExactInputSingleParams memory paramsUpdate = params; // U:[UNI3-3]
        paramsUpdate.recipient = creditAccount; // U:[UNI3-3]

        _executeSwapSafeApprove(params.tokenIn, abi.encodeCall(ISwapRouter.exactInputSingle, (paramsUpdate))); // U:[UNI3-3]
        return true;
    }

    /// @notice Swaps all balance of input token for output token through a single pool, except the specified amount
    /// @param params Swap params, see `ExactDiffInputSingleParams` for details
    function exactDiffInputSingle(ExactDiffInputSingleParams calldata params)
        external
        override
        creditFacadeOnly // U:[UNI3-2]
        returns (bool)
    {
        if (!isPoolAllowed(params.tokenIn, params.tokenOut, params.fee)) revert InvalidPathException();

        address creditAccount = _creditAccount(); // U:[UNI3-4]

        uint256 amount = IERC20(params.tokenIn).balanceOf(creditAccount); // U:[UNI3-4]
        if (amount <= params.leftoverAmount) return false;
        unchecked {
            amount -= params.leftoverAmount; // U:[UNI3-4]
        }

        ISwapRouter.ExactInputSingleParams memory paramsUpdate = ISwapRouter.ExactInputSingleParams({
            tokenIn: params.tokenIn,
            tokenOut: params.tokenOut,
            fee: params.fee,
            recipient: creditAccount,
            deadline: params.deadline,
            amountIn: amount,
            amountOutMinimum: (amount * params.rateMinRAY) / RAY,
            sqrtPriceLimitX96: params.sqrtPriceLimitX96
        }); // U:[UNI3-4]

        _executeSwapSafeApprove(params.tokenIn, abi.encodeCall(ISwapRouter.exactInputSingle, (paramsUpdate))); // U:[UNI3-4]
        return true;
    }

    /// @notice Swaps given amount of input token for output token through multiple pools
    /// @param params Swap params, see `ISwapRouter.ExactInputParams` for details
    /// @dev `params.recipient` is ignored since it can only be the credit account
    /// @dev `params.path` must have at most 3 hops through allowed pools
    function exactInput(ISwapRouter.ExactInputParams calldata params)
        external
        override
        creditFacadeOnly // U:[UNI3-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[UNI3-5]

        (bool valid, address tokenIn,) = _validatePath(params.path);
        if (!valid) revert InvalidPathException(); // U:[UNI3-5]

        ISwapRouter.ExactInputParams memory paramsUpdate = params; // U:[UNI3-5]
        paramsUpdate.recipient = creditAccount; // U:[UNI3-5]

        _executeSwapSafeApprove(tokenIn, abi.encodeCall(ISwapRouter.exactInput, (paramsUpdate))); // U:[UNI3-5]
        return true;
    }

    /// @notice Swaps all balance of input token for output token through multiple pools, except the specified amount
    /// @param params Swap params, see `ExactDiffInputParams` for details
    /// @dev `params.path` must have at most 3 hops through allowed pools
    function exactDiffInput(ExactDiffInputParams calldata params)
        external
        override
        creditFacadeOnly // U:[UNI3-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[UNI3-6]

        (bool valid, address tokenIn,) = _validatePath(params.path);
        if (!valid) revert InvalidPathException(); // U:[UNI3-6]

        uint256 amount = IERC20(tokenIn).balanceOf(creditAccount); // U:[UNI3-6]
        if (amount <= params.leftoverAmount) return false;

        unchecked {
            amount -= params.leftoverAmount; // U:[UNI3-6]
        }
        ISwapRouter.ExactInputParams memory paramsUpdate = ISwapRouter.ExactInputParams({
            path: params.path,
            recipient: creditAccount,
            deadline: params.deadline,
            amountIn: amount,
            amountOutMinimum: (amount * params.rateMinRAY) / RAY
        });

        _executeSwapSafeApprove(tokenIn, abi.encodeCall(ISwapRouter.exactInput, (paramsUpdate))); // U:[UNI3-6]
        return true;
    }

    /// @notice Swaps input token for given amount of output token through a single pool
    /// @param params Swap params, see `ISwapRouter.ExactOutputSingleParams` for details
    /// @dev `params.recipient` is ignored since it can only be the credit account
    function exactOutputSingle(ISwapRouter.ExactOutputSingleParams calldata params)
        external
        override
        creditFacadeOnly // U:[UNI3-2]
        returns (bool)
    {
        if (!isPoolAllowed(params.tokenIn, params.tokenOut, params.fee)) revert InvalidPathException();
        address creditAccount = _creditAccount(); // U:[UNI3-7]

        ISwapRouter.ExactOutputSingleParams memory paramsUpdate = params; // U:[UNI3-7]
        paramsUpdate.recipient = creditAccount; // U:[UNI3-7]

        _executeSwapSafeApprove(params.tokenIn, abi.encodeCall(ISwapRouter.exactOutputSingle, (paramsUpdate))); // U:[UNI3-7]
        return true;
    }

    /// @notice Swaps input token for given amount of output token through multiple pools
    /// @param params Swap params, see `ISwapRouter.ExactOutputParams` for details
    /// @dev `params.recipient` is ignored since it can only be the credit account
    /// @dev `params.path` must have at most 3 hops through allowed pools
    function exactOutput(ISwapRouter.ExactOutputParams calldata params)
        external
        override
        creditFacadeOnly // U:[UNI3-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[UNI3-8]

        (bool valid,, address tokenIn) = _validatePath(params.path);
        if (!valid) revert InvalidPathException(); // U:[UNI3-8]

        ISwapRouter.ExactOutputParams memory paramsUpdate = params; // U:[UNI3-8]
        paramsUpdate.recipient = creditAccount; // U:[UNI3-8]

        _executeSwapSafeApprove(tokenIn, abi.encodeCall(ISwapRouter.exactOutput, (paramsUpdate))); // U:[UNI3-8]
        return true;
    }

    // ---- //
    // DATA //
    // ---- //

    function supportedPools() public view returns (UniswapV3Pool[] memory pools) {
        bytes32[] memory poolHashes = _supportedPoolHashes.values();
        uint256 len = poolHashes.length;

        pools = new UniswapV3Pool[](len);

        for (uint256 i = 0; i < len; ++i) {
            pools[i] = _hashToPool[poolHashes[i]];
        }
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, supportedPools());
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Returns whether the (token0, token1, fee) pool is allowed to be traded through the adapter
    function isPoolAllowed(address token0, address token1, uint24 fee) public view override returns (bool) {
        (token0, token1) = _sortTokens(token0, token1);
        return _supportedPoolHashes.contains(keccak256(abi.encode(token0, token1, fee)));
    }

    /// @notice Sets status for a batch of pools
    /// @param pools Array of `UniswapV3PoolStatus` objects
    function setPoolStatusBatch(UniswapV3PoolStatus[] calldata pools)
        external
        override
        configuratorOnly // U:[UNI3-9]
    {
        uint256 len = pools.length;
        for (uint256 i; i < len; ++i) {
            (address token0, address token1) = _sortTokens(pools[i].token0, pools[i].token1);
            bytes32 poolHash = keccak256(abi.encode(token0, token1, pools[i].fee));
            if (pools[i].allowed) {
                /// For each added pool, we verify that the pool tokens are valid collaterals,
                /// as otherwise operations with unsupported tokens would be possible, leading
                /// to possibility of control flow capture
                _getMaskOrRevert(token0);
                _getMaskOrRevert(token1);

                _supportedPoolHashes.add(poolHash);
                _hashToPool[poolHash] = UniswapV3Pool({token0: token0, token1: token1, fee: pools[i].fee});
            } else {
                _supportedPoolHashes.remove(poolHash);
                delete _hashToPool[poolHash];
            }
            emit SetPoolStatus(token0, token1, pools[i].fee, pools[i].allowed); // U:[UNI3-9]
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
