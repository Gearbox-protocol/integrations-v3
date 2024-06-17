// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {IUniswapV2Router02} from "../../integrations/uniswap/IUniswapV2Router02.sol";
import {IUniswapV2Adapter, UniswapV2PairStatus, UniswapV2Pair} from "../../interfaces/uniswap/IUniswapV2Adapter.sol";

/// @title Uniswap V2 Router adapter
/// @notice Implements logic allowing CAs to perform swaps via Uniswap V2 and its forks
contract UniswapV2Adapter is AbstractAdapter, IUniswapV2Adapter {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    AdapterType public constant override _gearboxAdapterType = AdapterType.UNISWAP_V2_ROUTER;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @dev Mapping from hash(token0, token1) to respective tuple
    mapping(bytes32 => UniswapV2Pair) internal _hashToPair;

    /// @dev Set of hashes of (token0, token1) for all supported pools
    EnumerableSet.Bytes32Set internal _supportedPairHashes;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _router Uniswap V2 Router address
    constructor(address _creditManager, address _router)
        AbstractAdapter(_creditManager, _router) // U:[UNI2-1]
    {}

    /// @notice Swap input token for given amount of output token
    /// @param amountOut Amount of output token to receive
    /// @param amountInMax Maximum amount of input token to spend
    /// @param path Array of token addresses representing swap path, which must have at most 3 hops
    ///        through allowed pools
    /// @param deadline Maximum timestamp until which the transaction is valid
    /// @dev Parameter `to` is ignored since swap recipient can only be the credit account
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address,
        uint256 deadline
    )
        external
        override
        creditFacadeOnly // U:[UNI2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[UNI2-3]

        (bool valid, address tokenIn, address tokenOut) = _validatePath(path);
        if (!valid) revert InvalidPathException(); // U:[UNI2-3]

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            tokenIn,
            tokenOut,
            abi.encodeCall(
                IUniswapV2Router02.swapTokensForExactTokens, (amountOut, amountInMax, path, creditAccount, deadline)
            ),
            false
        ); // U:[UNI2-3]
    }

    /// @notice Swap given amount of input token to output token
    /// @param amountIn Amount of input token to spend
    /// @param amountOutMin Minumum amount of output token to receive
    /// @param path Array of token addresses representing swap path, which must have at most 3 hops
    ///        through allowed pools
    /// @param deadline Maximum timestamp until which the transaction is valid
    /// @dev Parameter `to` is ignored since swap recipient can only be the credit account
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address,
        uint256 deadline
    )
        external
        override
        creditFacadeOnly // U:[UNI2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[UNI2-4]

        (bool valid, address tokenIn, address tokenOut) = _validatePath(path);
        if (!valid) revert InvalidPathException(); // U:[UNI2-4]

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            tokenIn,
            tokenOut,
            abi.encodeCall(
                IUniswapV2Router02.swapExactTokensForTokens, (amountIn, amountOutMin, path, creditAccount, deadline)
            ),
            false
        ); // U:[UNI2-4]
    }

    /// @notice Swap the entire balance of input token to output token, except the specified amount
    /// @param leftoverAmount Amount of tokenIn to keep on the account
    /// @param rateMinRAY Minimum exchange rate between input and output tokens, scaled by 1e27
    /// @param path Array of token addresses representing swap path, which must have at most 3 hops
    ///        through allowed pools
    /// @param deadline Maximum timestamp until which the transaction is valid
    function swapDiffTokensForTokens(
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        address[] calldata path,
        uint256 deadline
    )
        external
        override
        creditFacadeOnly // U:[UNI2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[UNI2-5]

        address tokenIn;
        address tokenOut;

        {
            bool valid;
            (valid, tokenIn, tokenOut) = _validatePath(path);
            if (!valid) revert InvalidPathException(); // U:[UNI2-5]
        }

        uint256 amount = IERC20(tokenIn).balanceOf(creditAccount); // U:[UNI2-5]
        if (amount <= leftoverAmount) return (0, 0);

        unchecked {
            amount -= leftoverAmount; // U:[UNI2-5]
        }

        // calling `_executeSwap` because we need to check if output token is registered as collateral token in the CM
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            tokenIn,
            tokenOut,
            abi.encodeCall(
                IUniswapV2Router02.swapExactTokensForTokens,
                (amount, (amount * rateMinRAY) / RAY, path, creditAccount, deadline)
            ),
            leftoverAmount <= 1
        ); // U:[UNI2-5]
    }

    // ---- //
    // DATA //
    // ---- //

    function supportedPairs() public view returns (UniswapV2Pair[] memory pairs) {
        bytes32[] memory pairHashes = _supportedPairHashes.values();
        uint256 len = pairHashes.length;

        pairs = new UniswapV2Pair[](len);

        for (uint256 i = 0; i < len; ++i) {
            pairs[i] = _hashToPair[pairHashes[i]];
        }
    }

    /// @notice Returns all adapter parameters serialized into a bytes array,
    ///         as well as adapter type and version, to properly deserialize
    function serialize() external view returns (AdapterType, uint16, bytes[] memory) {
        UniswapV2Pair[] memory pairs = supportedPairs();

        bytes[] memory serializedData = new bytes[](3);
        serializedData[0] = abi.encode(creditManager);
        serializedData[1] = abi.encode(targetContract);
        serializedData[2] = abi.encode(pairs);

        return (_gearboxAdapterType, _gearboxAdapterVersion, serializedData);
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Returns whether the (token0, token1) pair is allowed to be traded through the adapter
    function isPairAllowed(address token0, address token1) public view override returns (bool) {
        (token0, token1) = _sortTokens(token0, token1);
        return _supportedPairHashes.contains(keccak256(abi.encode(token0, token1)));
    }

    /// @notice Sets status for a batch of pairs
    /// @param pairs Array of `UniswapV2PairStatus` objects
    function setPairStatusBatch(UniswapV2PairStatus[] calldata pairs)
        external
        override
        configuratorOnly // U:[UNI2-6]
    {
        uint256 len = pairs.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                (address token0, address token1) = _sortTokens(pairs[i].token0, pairs[i].token1);
                bytes32 pairHash = keccak256(abi.encode(token0, token1));
                if (pairs[i].allowed) {
                    _supportedPairHashes.add(pairHash);
                    _hashToPair[pairHash] = UniswapV2Pair({token0: token0, token1: token1});
                } else {
                    _supportedPairHashes.remove(pairHash);
                    delete _hashToPair[pairHash];
                }
                emit SetPairStatus(token0, token1, pairs[i].allowed); // U:[UNI2-6]
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
        if (len < 2 || len > 4) return (false, tokenIn, tokenOut); // U:[UNI2-7]

        tokenIn = path[0]; // U:[UNI2-7]
        tokenOut = path[len - 1]; // U:[UNI2-7]
        valid = isPairAllowed(path[0], path[1]);
        if (valid && len > 2) {
            valid = isPairAllowed(path[1], path[2]); // U:[UNI2-7]
            if (valid && len > 3) valid = isPairAllowed(path[2], path[3]); // U:[UNI2-7]
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
