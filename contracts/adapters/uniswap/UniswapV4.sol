// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IUniswapV4Gateway, PoolKey} from "../../interfaces/uniswap/IUniswapV4Gateway.sol";
import {IUniswapV4Adapter, UniswapV4PoolStatus} from "../../interfaces/uniswap/IUniswapV4Adapter.sol";

/// @title Uniswap V4 Router adapter
/// @notice Implements logic allowing CAs to perform swaps in Uniswap V4 pools via a gateway
contract UniswapV4Adapter is AbstractAdapter, IUniswapV4Adapter {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 public constant override contractType = "ADAPTER::UNISWAP_V4_GATEWAY";
    uint256 public constant override version = 3_10;

    address public immutable weth;

    /// @dev Mapping from hash(token0, token1, fee, tickSpacing, hooks) to respective tuple
    mapping(bytes32 => PoolKey) internal _hashToPoolKey;

    /// @dev Set of hashes of (token0, token1, fee, tickSpacing, hooks) for all supported pools
    EnumerableSet.Bytes32Set internal _supportedPoolKeyHashes;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _gateway UniswapV4 gateway address
    constructor(address _creditManager, address _gateway) AbstractAdapter(_creditManager, _gateway) {
        weth = IUniswapV4Gateway(_gateway).weth();
    }

    /// @notice Swaps given amount of input token for output token through a single pool
    /// @param poolKey Pool key
    /// @param zeroForOne Whether the input token is token0
    /// @param amountIn Amount of input token
    /// @param amountOutMinimum Minimum amount of output token
    /// @dev `hookData` is ignored since it is always set to empty for safety
    /// @dev In case the input token is ETH (denoted as address(0)), the gateway needs to have WETH approved to it
    function swapExactInputSingle(
        PoolKey calldata poolKey,
        bool zeroForOne,
        uint128 amountIn,
        uint128 amountOutMinimum,
        bytes calldata
    ) external creditFacadeOnly returns (bool) {
        if (!isPoolKeyAllowed(poolKey)) revert InvalidPoolKeyException();

        address tokenIn = zeroForOne ? poolKey.token0 : poolKey.token1;

        if (tokenIn == address(0)) tokenIn = weth;

        _swapExactInputSingle(poolKey, zeroForOne, amountIn, amountOutMinimum, tokenIn);

        return true;
    }

    /// @notice Swaps all balance of input token for output token through a single pool, except the specified amount
    /// @param poolKey Pool key
    /// @param zeroForOne Whether the input token is token0
    /// @param leftoverAmount Amount of input token to keep on the account
    /// @param rateMinRAY Minimum exchange rate between input and output tokens, scaled by 1e27
    /// @dev In case the input token is ETH (denoted as address(0)), the gateway needs to have WETH approved to it
    function swapExactInputSingleDiff(
        PoolKey calldata poolKey,
        bool zeroForOne,
        uint128 leftoverAmount,
        uint128 rateMinRAY
    ) external creditFacadeOnly returns (bool) {
        if (!isPoolKeyAllowed(poolKey)) revert InvalidPoolKeyException();

        address tokenIn = zeroForOne ? poolKey.token0 : poolKey.token1;

        if (tokenIn == address(0)) tokenIn = weth;

        address creditAccount = _creditAccount();

        uint256 amount = IERC20(tokenIn).balanceOf(creditAccount);
        if (amount <= leftoverAmount) return false;

        unchecked {
            amount -= leftoverAmount;
        }

        _swapExactInputSingle(poolKey, zeroForOne, uint128(amount), uint128(amount * rateMinRAY / RAY), tokenIn);

        return true;
    }

    /// @dev Internal implementation for `swapExactInputSingle` and `swapExactInputSingleDiff`
    function _swapExactInputSingle(
        PoolKey calldata poolKey,
        bool zeroForOne,
        uint128 amountIn,
        uint128 amountOutMinimum,
        address tokenIn
    ) internal {
        _executeSwapSafeApprove(
            tokenIn,
            abi.encodeCall(
                IUniswapV4Gateway.swapExactInputSingle, (poolKey, zeroForOne, amountIn, amountOutMinimum, "")
            )
        );
    }

    // ---- //
    // DATA //
    // ---- //

    /// @notice Returns all supported pool keys
    function supportedPoolKeys() public view returns (PoolKey[] memory poolKeys) {
        bytes32[] memory poolKeyHashes = _supportedPoolKeyHashes.values();
        uint256 len = poolKeyHashes.length;

        poolKeys = new PoolKey[](len);

        for (uint256 i = 0; i < len; ++i) {
            poolKeys[i] = _hashToPoolKey[poolKeyHashes[i]];
        }
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, supportedPoolKeys());
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Returns whether the (token0, token1, fee, tickSpacing, hooks) pool key is allowed to be traded through the adapter
    function isPoolKeyAllowed(PoolKey calldata poolKey) public view override returns (bool) {
        return _supportedPoolKeyHashes.contains(keccak256(abi.encode(poolKey)));
    }

    /// @notice Sets status for a batch of pool
    /// @param pools Array of `UniswapV4PoolStatus` objects
    function setPoolKeyStatusBatch(UniswapV4PoolStatus[] calldata pools) external override configuratorOnly {
        uint256 len = pools.length;
        for (uint256 i; i < len; ++i) {
            bytes32 poolKeyHash = keccak256(abi.encode(pools[i].poolKey));
            if (pools[i].allowed) {
                if (pools[i].poolKey.token0 == address(0)) {
                    _getMaskOrRevert(weth);
                } else {
                    _getMaskOrRevert(pools[i].poolKey.token0);
                }

                if (pools[i].poolKey.token1 == address(0)) {
                    _getMaskOrRevert(weth);
                } else {
                    _getMaskOrRevert(pools[i].poolKey.token1);
                }

                _supportedPoolKeyHashes.add(poolKeyHash);
                _hashToPoolKey[poolKeyHash] = pools[i].poolKey;
            } else {
                _supportedPoolKeyHashes.remove(poolKeyHash);
                delete _hashToPoolKey[poolKeyHash];
            }
            emit SetPoolKeyStatus(
                pools[i].poolKey.token0,
                pools[i].poolKey.token1,
                pools[i].poolKey.fee,
                pools[i].poolKey.tickSpacing,
                pools[i].poolKey.hooks,
                pools[i].allowed
            );
        }
    }
}
