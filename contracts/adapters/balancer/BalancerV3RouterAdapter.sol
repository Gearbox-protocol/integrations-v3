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
import {
    IBalancerV3RouterAdapter,
    BalancerV3PoolStatus,
    PoolStatus
} from "../../interfaces/balancer/IBalancerV3RouterAdapter.sol";

/// @title Balancer V3 Router adapter
/// @notice Implements logic allowing CAs to perform swaps via Balancer V3
contract BalancerV3RouterAdapter is AbstractAdapter, IBalancerV3RouterAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::BALANCER_V3_ROUTER";
    uint256 public constant override version = 3_11;

    /// @dev Set of all pools that are currently allowed
    EnumerableSet.AddressSet internal _allowedPools;

    /// @dev Allowance status for each pool
    mapping(address => PoolStatus) internal _poolStatus;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _router Balancer V3 Router address
    constructor(address _creditManager, address _router) AbstractAdapter(_creditManager, _router) {}

    /// ---- ///
    /// SWAP ///
    /// ---- ///

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
        if (!_swapAllowed(pool)) revert InvalidPoolException();

        _swapSingleTokenExactIn(pool, tokenIn, tokenOut, exactAmountIn, minAmountOut, deadline);
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
        if (!_swapAllowed(pool)) revert InvalidPoolException();

        address creditAccount = _creditAccount();

        uint256 amount = _getAmountOverLeftover(tokenIn, leftoverAmount, creditAccount);

        _swapSingleTokenExactIn(pool, tokenIn, tokenOut, amount, (amount * rateMinRAY) / RAY, deadline);

        return true;
    }

    /// @dev Internal function for `swapSingleTokenExactIn`
    function _swapSingleTokenExactIn(
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amount,
        uint256 minAmountOut,
        uint256 deadline
    ) internal {
        _executeSwapSafeApprove(
            address(tokenIn),
            abi.encodeCall(
                IBalancerV3Router.swapSingleTokenExactIn,
                (pool, tokenIn, tokenOut, amount, minAmountOut, deadline, false, "")
            )
        );
    }

    /// ------------- //
    /// ADD LIQUIDITY //
    /// ------------- //

    /// @notice Adds liquidity to a pool with exact amounts of tokens
    /// @param pool Pool address
    /// @param exactAmountsIn Amount of each token to add
    /// @param minBptAmountOut Minimum amount of BPT to receive
    /// @dev wethIsEth and userData are ignored, since they are always set to false and empty
    function addLiquidityUnbalanced(
        address pool,
        uint256[] calldata exactAmountsIn,
        uint256 minBptAmountOut,
        bool,
        bytes calldata
    ) external creditFacadeOnly returns (bool) {
        if (!_depositAllowed(pool)) revert InvalidPoolException();

        IERC20[] memory tokens = IBalancerV3Pool(pool).getTokens();

        if (exactAmountsIn.length != tokens.length) revert InvalidLengthException();

        _addLiquidityUnbalanced(pool, tokens, exactAmountsIn, minBptAmountOut);

        return true;
    }

    /// @notice Adds liquidity to a pool, using full balances of tokens except the specified amount
    /// @param pool Pool address
    /// @param leftoverAmounts Amount of each token to keep on the account
    /// @param minRatesRAY Minimum exchange rate [RAY] for each token
    function addLiquidityUnbalancedDiff(
        address pool,
        uint256[] calldata leftoverAmounts,
        uint256[] calldata minRatesRAY
    ) external creditFacadeOnly returns (bool) {
        if (!_depositAllowed(pool)) revert InvalidPoolException();

        address creditAccount = _creditAccount();

        IERC20[] memory tokens = IBalancerV3Pool(pool).getTokens();

        uint256 len = tokens.length;

        if (leftoverAmounts.length != tokens.length) revert InvalidLengthException();
        if (minRatesRAY.length != tokens.length) revert InvalidLengthException();

        uint256[] memory exactAmountsIn = new uint256[](len);
        uint256 minBptOut = 0;

        for (uint256 i = 0; i < len; ++i) {
            exactAmountsIn[i] = _getAmountOverLeftover(tokens[i], leftoverAmounts[i], creditAccount);
            minBptOut += (exactAmountsIn[i] * minRatesRAY[i]) / RAY;
        }

        _addLiquidityUnbalanced(pool, tokens, exactAmountsIn, minBptOut);

        return true;
    }

    /// @dev Internal function to add liquidity to a pool with exact amounts of tokens
    function _addLiquidityUnbalanced(
        address pool,
        IERC20[] memory tokens,
        uint256[] memory exactAmountsIn,
        uint256 minBptAmountOut
    ) internal {
        uint256 len = exactAmountsIn.length;
        for (uint256 i = 0; i < len; ++i) {
            _approveToken(address(tokens[i]), type(uint256).max);
        }
        _execute(
            abi.encodeCall(IBalancerV3Router.addLiquidityUnbalanced, (pool, exactAmountsIn, minBptAmountOut, false, ""))
        );
        for (uint256 i = 0; i < len; ++i) {
            _approveToken(address(tokens[i]), 1);
        }
    }

    /// ---------------- ///
    /// REMOVE LIQUIDITY ///
    /// ---------------- ///

    /// @notice Removes liquidity from a pool with an exact amount of BPT
    /// @param pool Pool address
    /// @param exactBptAmountIn Amount of BPT to remove
    /// @param tokenOut Token to remove liquidity to
    /// @param minAmountOut Minimum amount of tokenOut to receive
    /// @dev wethIsEth and userData are ignored, since they are always set to false and empty
    function removeLiquiditySingleTokenExactIn(
        address pool,
        uint256 exactBptAmountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        bool,
        bytes calldata
    ) external creditFacadeOnly returns (bool) {
        if (!_exitAllowed(pool)) revert InvalidPoolException();

        _removeLiquiditySingleTokenExactIn(pool, exactBptAmountIn, tokenOut, minAmountOut);
        return true;
    }

    /// @notice Removes liquidity from a pool, using full balance of BPT except the specified amount
    /// @param pool Pool address
    /// @param leftoverAmount Amount of BPT to keep on the account
    /// @param tokenOut Token to remove liquidity to
    /// @param minRateRAY Minimum exchange rate [RAY] for the token
    function removeLiquiditySingleTokenDiff(address pool, uint256 leftoverAmount, IERC20 tokenOut, uint256 minRateRAY)
        external
        creditFacadeOnly
        returns (bool)
    {
        if (!_exitAllowed(pool)) revert InvalidPoolException();

        address creditAccount = _creditAccount();

        uint256 amount = _getAmountOverLeftover(IERC20(pool), leftoverAmount, creditAccount);
        uint256 minAmountOut = (amount * minRateRAY) / RAY;

        _removeLiquiditySingleTokenExactIn(pool, amount, tokenOut, minAmountOut);
        return true;
    }

    /// @dev Internal function for `removeLiquiditySingleTokenDiff`
    function _removeLiquiditySingleTokenExactIn(address pool, uint256 amount, IERC20 tokenOut, uint256 minAmountOut)
        internal
    {
        _executeSwapSafeApprove(
            pool,
            abi.encodeCall(
                IBalancerV3Router.removeLiquiditySingleTokenExactIn, (pool, amount, tokenOut, minAmountOut, false, "")
            )
        );
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Returns whether the pool is allowed to be traded through the adapter
    function poolStatus(address pool) public view override returns (PoolStatus) {
        return _poolStatus[pool];
    }

    /// @notice Returns the list of all pools that were ever allowed in this adapter
    function getAllowedPools() public view override returns (BalancerV3PoolStatus[] memory pools) {
        uint256 len = _allowedPools.length();
        pools = new BalancerV3PoolStatus[](len);
        for (uint256 i; i < len; ++i) {
            address pool = _allowedPools.at(i);
            pools[i] = BalancerV3PoolStatus({pool: pool, status: _poolStatus[pool]});
        }
        return pools;
    }

    /// @notice Sets status for a batch of pools
    /// @param pools Array of pool addresses and statuses
    function setPoolStatusBatch(BalancerV3PoolStatus[] calldata pools) external override configuratorOnly {
        uint256 len = pools.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                _poolStatus[pools[i].pool] = pools[i].status;
                if (pools[i].status == PoolStatus.ALLOWED || pools[i].status == PoolStatus.EXIT_ONLY) {
                    IERC20[] memory tokens = IBalancerV3Pool(pools[i].pool).getTokens();
                    for (uint256 j; j < tokens.length; ++j) {
                        _getMaskOrRevert(address(tokens[j]));
                    }
                    _getMaskOrRevert(pools[i].pool);
                    _allowedPools.add(pools[i].pool);
                } else if (pools[i].status == PoolStatus.SWAP_ONLY) {
                    IERC20[] memory tokens = IBalancerV3Pool(pools[i].pool).getTokens();
                    for (uint256 j; j < tokens.length; ++j) {
                        _getMaskOrRevert(address(tokens[j]));
                    }
                    _allowedPools.add(pools[i].pool);
                } else {
                    _allowedPools.remove(pools[i].pool);
                }
                emit SetPoolStatus(pools[i].pool, pools[i].status);
            }
        }
    }

    // ----- //
    // UTILS //
    // ----- //

    /// @dev Internal function to check if swaps are allowed for a pool.
    function _swapAllowed(address pool) internal view returns (bool) {
        return _poolStatus[pool] == PoolStatus.ALLOWED || _poolStatus[pool] == PoolStatus.SWAP_ONLY;
    }

    /// @dev Internal function to check if withdrawals are allowed for a pool.
    function _exitAllowed(address pool) internal view returns (bool) {
        return _poolStatus[pool] == PoolStatus.ALLOWED || _poolStatus[pool] == PoolStatus.EXIT_ONLY;
    }

    /// @dev Internal function to check if deposits are allowed for a pool.
    function _depositAllowed(address pool) internal view returns (bool) {
        return _poolStatus[pool] == PoolStatus.ALLOWED;
    }

    /// @dev Internal function to get the amount of tokens over the leftover amount.
    function _getAmountOverLeftover(IERC20 token, uint256 leftoverAmount, address creditAccount)
        internal
        view
        returns (uint256 amount)
    {
        amount = token.balanceOf(creditAccount);
        if (amount > leftoverAmount) {
            amount -= leftoverAmount;
        } else {
            amount = 0;
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
