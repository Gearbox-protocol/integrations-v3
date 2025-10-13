// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {IBalancerV3Router} from "../../integrations/balancer/IBalancerV3Router.sol";
import {IBalancerV3Pool} from "../../integrations/balancer/IBalancerV3Pool.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

/// @title BalancerV3RouterGateway
/// @dev This is connector contract to allow Gearbox adapters to swap through the Balancer V3 Router.
///      Since the router requires the caller to approve inputs in Permit2, we need an intermediate contract,
///      which will be approved to spend the inputs and then call the Permit2 and the router.
contract BalancerV3RouterGateway is IBalancerV3Router, IVersion {
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::BALANCER_V3";
    uint256 public constant override version = 3_11;

    address public immutable balancerV3Router;
    address public immutable permit2;

    constructor(address _balancerV3Router, address _permit2) {
        balancerV3Router = _balancerV3Router;
        permit2 = _permit2;
    }

    /// @dev Swaps an exact amount of input token for an output token
    /// @param pool Address of the pool to swap through
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @param exactAmountIn Amount of input token to swap
    /// @param minAmountOut Minimum amount of output token to receive
    /// @param deadline Deadline for the swap
    /// @param wethIsEth Whether WETH is ETH
    /// @param userData Additional data for the swap
    /// @return amountOut Amount of output token received
    function swapSingleTokenExactIn(
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 exactAmountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    ) external returns (uint256 amountOut) {
        exactAmountIn = _transferTokenIn(tokenIn, exactAmountIn);

        tokenIn.forceApprove(permit2, exactAmountIn);
        IPermit2(permit2).approve(address(tokenIn), balancerV3Router, uint160(exactAmountIn), uint48(block.timestamp));

        IBalancerV3Router(balancerV3Router).swapSingleTokenExactIn(
            pool, tokenIn, tokenOut, exactAmountIn, minAmountOut, deadline, wethIsEth, userData
        );

        amountOut = _transferBalance(tokenOut);

        tokenIn.forceApprove(permit2, 1);

        return amountOut;
    }

    /// @dev Adds liquidity to a pool with an unbalanced amount of tokens
    /// @param pool Address of the pool to add liquidity to
    /// @param exactAmountsIn Amount of each token to add
    /// @param minBptAmountOut Minimum amount of BPT to receive
    /// @param wethIsEth Whether WETH is ETH
    /// @param userData Additional data for the add liquidity
    /// @return bptAmountOut Amount of BPT received
    function addLiquidityUnbalanced(
        address pool,
        uint256[] memory exactAmountsIn,
        uint256 minBptAmountOut,
        bool wethIsEth,
        bytes memory userData
    ) external returns (uint256 bptAmountOut) {
        IERC20[] memory tokens = IBalancerV3Pool(pool).getTokens();

        if (exactAmountsIn.length != tokens.length) revert("BalanceV3RouterGateway: amounts array length mismatch");

        for (uint256 i; i < tokens.length; ++i) {
            exactAmountsIn[i] = _transferTokenIn(tokens[i], exactAmountsIn[i]);
            tokens[i].forceApprove(permit2, exactAmountsIn[i]);
            IPermit2(permit2).approve(
                address(tokens[i]), balancerV3Router, uint160(exactAmountsIn[i]), uint48(block.timestamp)
            );
        }

        IBalancerV3Router(balancerV3Router).addLiquidityUnbalanced(
            pool, exactAmountsIn, minBptAmountOut, wethIsEth, userData
        );

        bptAmountOut = _transferBalance(IERC20(pool));

        for (uint256 i; i < tokens.length; ++i) {
            tokens[i].forceApprove(permit2, 1);
        }

        return bptAmountOut;
    }

    /// @dev Removes liquidity from a pool with an exact amount of BPT
    /// @param pool Address of the pool to remove liquidity from
    /// @param exactBptAmountIn Amount of BPT to remove
    /// @param tokenOut Token to remove liquidity to
    /// @param minAmountOut Minimum amount of tokenOut to receive
    /// @param wethIsEth Whether WETH is ETH
    /// @param userData Additional data for the remove liquidity
    /// @return amountOut Amount of tokenOut received
    function removeLiquiditySingleTokenExactIn(
        address pool,
        uint256 exactBptAmountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        bool wethIsEth,
        bytes memory userData
    ) external returns (uint256 amountOut) {
        exactBptAmountIn = _transferTokenIn(IERC20(pool), exactBptAmountIn);
        minAmountOut = minAmountOut == 0 ? 1 : minAmountOut;

        IERC20(pool).forceApprove(balancerV3Router, exactBptAmountIn);

        IBalancerV3Router(balancerV3Router).removeLiquiditySingleTokenExactIn(
            pool, exactBptAmountIn, tokenOut, minAmountOut, wethIsEth, userData
        );

        amountOut = _transferBalance(tokenOut);

        IERC20(pool).forceApprove(balancerV3Router, 1);
    }

    /// @dev Transfers a token to this contract from msg.sender and returns the amount transferred
    /// @param token Token to transfer
    /// @param amount Amount to transfer
    function _transferTokenIn(IERC20 token, uint256 amount) internal returns (uint256 transferredAmount) {
        uint256 balanceBefore = token.balanceOf(address(this));

        token.safeTransferFrom(msg.sender, address(this), amount);

        return token.balanceOf(address(this)) - balanceBefore;
    }

    /// @dev Transfers the current balance of a token to sender (minus 1 for gas savings) and returns the amount transferred
    /// @param token Token to transfer
    function _transferBalance(IERC20 token) internal returns (uint256 transferredAmount) {
        uint256 balance = token.balanceOf(address(this));
        if (balance > 1) {
            unchecked {
                token.safeTransfer(msg.sender, balance - 1);
            }
            return balance - 1;
        }
        return 0;
    }

    /// @dev The receive function is required in case Balancer sends back ETH. It is intended for received ETH to be unrecoverable.
    receive() external payable {}
}
