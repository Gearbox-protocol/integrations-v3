// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IBalancerV3Router} from "../../integrations/balancer/IBalancerV3Router.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

/// @title BalancerV3RouterGateway
/// @dev This is connector contract to allow Gearbox adapters to swap through the Balancer V3 Router.
///      Since the router requires the caller to approve inputs in Permit2, we need an intermediate contract,
///      which will be approved to spend the inputs and then call the Permit2 and the router.
contract BalancerV3RouterGateway is IBalancerV3Router {
    using SafeERC20 for IERC20;

    address public immutable balancerV3Router;
    address public immutable permit2;

    constructor(address _balancerV3Router, address _permit2) {
        balancerV3Router = _balancerV3Router;
        permit2 = _permit2;
    }

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
        uint256 balanceBefore = tokenIn.balanceOf(address(this));

        tokenIn.safeTransferFrom(msg.sender, address(this), exactAmountIn);

        exactAmountIn = tokenIn.balanceOf(address(this)) - balanceBefore;

        tokenIn.forceApprove(permit2, exactAmountIn);
        IPermit2(permit2).approve(address(tokenIn), balancerV3Router, uint160(exactAmountIn), uint48(block.timestamp));

        IBalancerV3Router(balancerV3Router).swapSingleTokenExactIn(
            pool, tokenIn, tokenOut, exactAmountIn, minAmountOut, deadline, wethIsEth, userData
        );

        amountOut = _transferBalance(tokenOut);

        tokenIn.forceApprove(permit2, 1);

        return amountOut;
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
