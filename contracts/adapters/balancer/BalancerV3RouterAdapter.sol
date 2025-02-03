// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IBalancerV3Router} from "../../integrations/balancer/IBalancerV3Router.sol";
import {IBalancerV3Pool} from "../../integrations/balancer/IBalancerV3Pool.sol";
import {IBalancerV3RouterAdapter} from "../../interfaces/balancer/IBalancerV3RouterAdapter.sol";

/// @title Balancer V3 Router adapter
/// @notice Implements logic allowing CAs to perform swaps via Balancer V3
contract BalancerV3RouterAdapter is AbstractAdapter, IBalancerV3RouterAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "AD_BALANCER_V3_ROUTER";
    uint256 public constant override version = 3_10;

    /// @dev Mapping from pool address to whether it can be traded through the adapter
    mapping(address => bool) internal _poolStatus;

    /// @dev Set of all pools that are currently allowed
    EnumerableSet.AddressSet internal _allowedPools;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _router Balancer V3 Router address
    constructor(address _creditManager, address _router) AbstractAdapter(_creditManager, _router) {}

    /// @notice Swaps given amount of input token for output token through a single pool
    /// @param pool Pool address
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @param exactAmountIn Exact amount of input token to swap
    /// @param minAmountOut Minimum amount of output token to receive
    /// @param deadline Deadline for the swap
    /// @dev wethIsEth and userData are ignored, since they are always set to false and empty
    function swapSingleTokenExactIn(
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 exactAmountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bool,
        bytes calldata
    ) external override creditFacadeOnly returns (bool) {
        if (!isPoolAllowed(pool)) revert InvalidPoolException();

        _executeSwapSafeApprove(
            address(tokenIn),
            abi.encodeCall(
                IBalancerV3Router.swapSingleTokenExactIn,
                (pool, tokenIn, tokenOut, exactAmountIn, minAmountOut, deadline, false, "")
            )
        );
        return true;
    }

    /// @notice Swaps all balance of input token for output token through a single pool, except the specified amount
    /// @param pool Pool address
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @param leftoverAmount Amount of input token to keep
    /// @param rateMinRAY Minimum exchange rate [RAY]
    /// @param deadline Deadline for the swap
    function swapSingleTokenDiffIn(
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        uint256 deadline
    ) external override creditFacadeOnly returns (bool) {
        if (!isPoolAllowed(pool)) revert InvalidPoolException();

        address creditAccount = _creditAccount();

        uint256 amount = IERC20(address(tokenIn)).balanceOf(creditAccount);
        if (amount <= leftoverAmount) return false;
        unchecked {
            amount -= leftoverAmount;
        }

        _executeSwapSafeApprove(
            address(tokenIn),
            abi.encodeCall(
                IBalancerV3Router.swapSingleTokenExactIn,
                (pool, tokenIn, tokenOut, amount, (amount * rateMinRAY) / RAY, deadline, false, "")
            )
        );
        return true;
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Returns whether the pool is allowed to be traded through the adapter
    function isPoolAllowed(address pool) public view override returns (bool) {
        return _poolStatus[pool];
    }

    /// @notice Returns the list of all pools that were ever allowed in this adapter
    function getAllowedPools() public view override returns (address[] memory pools) {
        return _allowedPools.values();
    }

    /// @notice Sets status for a batch of pools
    /// @param pools Array of pool addresses
    /// @param statuses Array of pool statuses
    function setPoolStatusBatch(address[] calldata pools, bool[] calldata statuses)
        external
        override
        configuratorOnly
    {
        uint256 len = pools.length;
        if (len != statuses.length) revert InvalidLengthException();
        unchecked {
            for (uint256 i; i < len; ++i) {
                address pool = pools[i];
                bool status = statuses[i];

                if (status) {
                    // Verify that all tokens in the pool are valid collaterals
                    IERC20[] memory tokens = IBalancerV3Pool(pool).getTokens();
                    for (uint256 j; j < tokens.length; ++j) {
                        _getMaskOrRevert(address(tokens[j]));
                    }
                }

                _poolStatus[pool] = status;
                if (status) {
                    _allowedPools.add(pool);
                } else {
                    _allowedPools.remove(pool);
                }
                emit SetPoolStatus(pool, status);
            }
        }
    }

    // ---- //
    // DATA //
    // ---- //

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, getAllowedPools());
    }
}
