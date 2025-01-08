// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {ICamelotV3Router} from "../../integrations/camelot/ICamelotV3Router.sol";
import {BytesLib} from "../../integrations/uniswap/BytesLib.sol";
import {ICamelotV3Adapter, CamelotV3PoolStatus, CamelotV3Pool} from "../../interfaces/camelot/ICamelotV3Adapter.sol";

/// @title Camelot V3 Router adapter
/// @notice Implements logic allowing CAs to perform swaps via Camelot V3
contract CamelotV3Adapter is AbstractAdapter, ICamelotV3Adapter {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using BytesLib for bytes;

    bytes32 public constant override contractType = "ADAPTER::CAMELOT_V3_ROUTER";
    uint256 public constant override version = 3_10;

    /// @dev The length of the bytes encoded address
    uint256 private constant ADDR_SIZE = 20;

    /// @dev The offset of a single token address and pool fee
    uint256 private constant NEXT_OFFSET = ADDR_SIZE;

    /// @dev The length of the path with 1 hop
    uint256 private constant PATH_2_LENGTH = 2 * ADDR_SIZE;

    /// @dev The length of the path with 2 hops
    uint256 private constant PATH_3_LENGTH = 3 * ADDR_SIZE;

    /// @dev The length of the path with 3 hops
    uint256 private constant PATH_4_LENGTH = 4 * ADDR_SIZE;

    /// @dev Mapping from hash(token0, token1) to respective tuple
    mapping(bytes32 => CamelotV3Pool) internal _hashToPool;

    /// @dev Set of hashes of (token0, token1) for all supported pools
    EnumerableSet.Bytes32Set internal _supportedPoolHashes;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _router Camelot V3 Router address
    constructor(address _creditManager, address _router) AbstractAdapter(_creditManager, _router) {} // U: [CAMV3-1]

    /// @notice Swaps given amount of input token for output token through a single pool
    /// @param params Swap params, see `ICamelotV3Router.ExactInputSingleParams` for details
    /// @dev `params.recipient` is ignored since it can only be the credit account
    function exactInputSingle(ICamelotV3Router.ExactInputSingleParams calldata params)
        external
        override
        creditFacadeOnly // U: [CAMV3-2]
        returns (bool)
    {
        _exactInputSingleInternal(params, false); // U: [CAMV3-3]
        return true;
    }

    /// @notice Swaps given amount of input token for output token through a single pool, supporting fee on transfer tokens
    /// @param params Swap params, see `ICamelotV3Router.ExactInputSingleParams` for details
    /// @dev `params.recipient` is ignored since it can only be the credit account
    function exactInputSingleSupportingFeeOnTransferTokens(ICamelotV3Router.ExactInputSingleParams calldata params)
        external
        override
        creditFacadeOnly // U: [CAMV3-2]
        returns (bool)
    {
        _exactInputSingleInternal(params, true); // U: [CAMV3-3A]
        return true;
    }

    /// @dev Internal logic for `exactInputSingle` and `exactInputSingleSupportingFeeOnTransferTokens`
    function _exactInputSingleInternal(ICamelotV3Router.ExactInputSingleParams calldata params, bool isFeeOnTransfer)
        internal
    {
        if (!isPoolAllowed(params.tokenIn, params.tokenOut)) revert InvalidPathException();

        address creditAccount = _creditAccount();

        ICamelotV3Router.ExactInputSingleParams memory paramsUpdate = params;
        paramsUpdate.recipient = creditAccount;

        bytes memory callData = isFeeOnTransfer
            ? abi.encodeCall(ICamelotV3Router.exactInputSingleSupportingFeeOnTransferTokens, (paramsUpdate))
            : abi.encodeCall(ICamelotV3Router.exactInputSingle, (paramsUpdate));

        _executeSwapSafeApprove(params.tokenIn, callData);
    }

    /// @notice Swaps all balance of input token for output token through a single pool, except the specified amount
    /// @param params Swap params, see `ExactDiffInputSingleParams` for details
    function exactDiffInputSingle(ExactDiffInputSingleParams calldata params)
        external
        override
        creditFacadeOnly // U: [CAMV3-2]
        returns (bool)
    {
        return _exactDiffInputSingleInternal(params, false); // U: [CAMV3-4]
    }

    /// @notice Swaps all balance of input token for output token through a single pool, except the specified amount
    /// @param params Swap params, see `ExactDiffInputSingleParams` for details
    function exactDiffInputSingleSupportingFeeOnTransferTokens(ExactDiffInputSingleParams calldata params)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        return _exactDiffInputSingleInternal(params, true); // U: [CAMV3-4A]
    }

    /// @dev Internal logic for `exactDiffInputSingle` and `exactDiffInputSingleSupportingFeeOnTransferTokens`
    function _exactDiffInputSingleInternal(ExactDiffInputSingleParams calldata params, bool isFeeOnTransfer)
        internal
        returns (bool)
    {
        if (!isPoolAllowed(params.tokenIn, params.tokenOut)) revert InvalidPathException();

        address creditAccount = _creditAccount();

        uint256 amount = IERC20(params.tokenIn).balanceOf(creditAccount);
        if (amount <= params.leftoverAmount) return false;
        unchecked {
            amount -= params.leftoverAmount;
        }

        ICamelotV3Router.ExactInputSingleParams memory paramsUpdate = ICamelotV3Router.ExactInputSingleParams({
            tokenIn: params.tokenIn,
            tokenOut: params.tokenOut,
            recipient: creditAccount,
            deadline: params.deadline,
            amountIn: amount,
            amountOutMinimum: (amount * params.rateMinRAY) / RAY,
            limitSqrtPrice: params.limitSqrtPrice
        });

        bytes memory callData = isFeeOnTransfer
            ? abi.encodeCall(ICamelotV3Router.exactInputSingleSupportingFeeOnTransferTokens, (paramsUpdate))
            : abi.encodeCall(ICamelotV3Router.exactInputSingle, (paramsUpdate));

        _executeSwapSafeApprove(params.tokenIn, callData);
        return true;
    }

    /// @notice Swaps given amount of input token for output token through multiple pools
    /// @param params Swap params, see `ICamelotV3Router.ExactInputParams` for details
    /// @dev `params.recipient` is ignored since it can only be the credit account
    /// @dev `params.path` must have at most 3 hops through allowed pools
    function exactInput(ICamelotV3Router.ExactInputParams calldata params)
        external
        override
        creditFacadeOnly // U: [CAMV3-2]
        returns (bool)
    {
        address creditAccount = _creditAccount();

        (bool valid, address tokenIn,) = _validatePath(params.path);
        if (!valid) revert InvalidPathException();

        ICamelotV3Router.ExactInputParams memory paramsUpdate = params;
        paramsUpdate.recipient = creditAccount;

        _executeSwapSafeApprove(tokenIn, abi.encodeCall(ICamelotV3Router.exactInput, (paramsUpdate))); // U: [CAMV3-5]
        return true;
    }

    /// @notice Swaps all balance of input token for output token through multiple pools, except the specified amount
    /// @param params Swap params, see `ExactDiffInputParams` for details
    /// @dev `params.path` must have at most 3 hops through allowed pools
    function exactDiffInput(ExactDiffInputParams calldata params)
        external
        override
        creditFacadeOnly // U: [CAMV3-2]
        returns (bool)
    {
        address creditAccount = _creditAccount();

        (bool valid, address tokenIn,) = _validatePath(params.path);
        if (!valid) revert InvalidPathException();

        uint256 amount = IERC20(tokenIn).balanceOf(creditAccount);
        if (amount <= params.leftoverAmount) return false;

        unchecked {
            amount -= params.leftoverAmount;
        }
        ICamelotV3Router.ExactInputParams memory paramsUpdate = ICamelotV3Router.ExactInputParams({
            path: params.path,
            recipient: creditAccount,
            deadline: params.deadline,
            amountIn: amount,
            amountOutMinimum: (amount * params.rateMinRAY) / RAY
        });

        _executeSwapSafeApprove(tokenIn, abi.encodeCall(ICamelotV3Router.exactInput, (paramsUpdate))); // U: [CAMV3-6]
        return true;
    }

    /// @notice Swaps input token for given amount of output token through a single pool
    /// @param params Swap params, see `ICamelotV3Router.ExactOutputSingleParams` for details
    /// @dev `params.recipient` is ignored since it can only be the credit account
    function exactOutputSingle(ICamelotV3Router.ExactOutputSingleParams calldata params)
        external
        override
        creditFacadeOnly // U: [CAMV3-2]
        returns (bool)
    {
        if (!isPoolAllowed(params.tokenIn, params.tokenOut)) revert InvalidPathException();
        address creditAccount = _creditAccount();

        ICamelotV3Router.ExactOutputSingleParams memory paramsUpdate = params;
        paramsUpdate.recipient = creditAccount;

        _executeSwapSafeApprove(params.tokenIn, abi.encodeCall(ICamelotV3Router.exactOutputSingle, (paramsUpdate))); // U: [CAMV3-7]
        return true;
    }

    /// @notice Swaps input token for given amount of output token through multiple pools
    /// @param params Swap params, see `ICamelotV3Router.ExactOutputParams` for details
    /// @dev `params.recipient` is ignored since it can only be the credit account
    /// @dev `params.path` must have at most 3 hops through allowed pools
    function exactOutput(ICamelotV3Router.ExactOutputParams calldata params)
        external
        override
        creditFacadeOnly // U: [CAMV3-2]
        returns (bool)
    {
        address creditAccount = _creditAccount();

        (bool valid,, address tokenIn) = _validatePath(params.path);
        if (!valid) revert InvalidPathException();

        ICamelotV3Router.ExactOutputParams memory paramsUpdate = params;
        paramsUpdate.recipient = creditAccount;

        _executeSwapSafeApprove(tokenIn, abi.encodeCall(ICamelotV3Router.exactOutput, (paramsUpdate))); // U: [CAMV3-8]
        return true;
    }

    // ---- //
    // DATA //
    // ---- //

    function supportedPools() public view returns (CamelotV3Pool[] memory pools) {
        bytes32[] memory poolHashes = _supportedPoolHashes.values();
        uint256 len = poolHashes.length;

        pools = new CamelotV3Pool[](len);

        for (uint256 i = 0; i < len; ++i) {
            pools[i] = _hashToPool[poolHashes[i]];
        }
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        CamelotV3Pool[] memory pools = supportedPools();

        serializedData = abi.encode(creditManager, targetContract, pools);
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Returns whether the (token0, token1, fee) pool is allowed to be traded through the adapter
    function isPoolAllowed(address token0, address token1) public view override returns (bool) {
        (token0, token1) = _sortTokens(token0, token1);
        return _supportedPoolHashes.contains(keccak256(abi.encode(token0, token1)));
    }

    /// @notice Sets status for a batch of pools
    /// @param pools Array of `CamelotV3PoolStatus` objects
    function setPoolStatusBatch(CamelotV3PoolStatus[] calldata pools) external override configuratorOnly {
        uint256 len = pools.length;
        for (uint256 i; i < len; ++i) {
            (address token0, address token1) = _sortTokens(pools[i].token0, pools[i].token1);

            bytes32 poolHash = keccak256(abi.encode(token0, token1));
            if (pools[i].allowed) {
                /// For each added pool, we verify that the pool tokens are valid collaterals,
                /// as otherwise operations with unsupported tokens would be possible, leading
                /// to possibility of control flow capture
                _getMaskOrRevert(token0);
                _getMaskOrRevert(token1);

                _supportedPoolHashes.add(poolHash);
                _hashToPool[poolHash] = CamelotV3Pool({token0: token0, token1: token1});
            } else {
                _supportedPoolHashes.remove(poolHash);
                delete _hashToPool[poolHash];
            }
            emit SetPoolStatus(token0, token1, pools[i].allowed); // U: [CAMV3-9]
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
        if (len != PATH_2_LENGTH && len != PATH_3_LENGTH && len != PATH_4_LENGTH) return (false, tokenIn, tokenOut); // U: [CAMV3-10]

        tokenIn = path.toAddress(0);
        tokenOut = path.toAddress(NEXT_OFFSET);
        valid = isPoolAllowed(tokenIn, tokenOut); // U: [CAMV3-10]

        if (valid && len > PATH_2_LENGTH) {
            address tokenMid = tokenOut;
            tokenOut = path.toAddress(2 * NEXT_OFFSET);
            valid = isPoolAllowed(tokenMid, tokenOut); // U: [CAMV3-10]

            if (valid && len > PATH_3_LENGTH) {
                tokenMid = tokenOut;
                tokenOut = path.toAddress(3 * NEXT_OFFSET);
                valid = isPoolAllowed(tokenMid, tokenOut); // U: [CAMV3-10]
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
