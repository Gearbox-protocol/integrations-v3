// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {
    IUniversalRouter,
    UniswapV4ExactInputSingleParams,
    PoolKey,
    COMMAND_V4_SWAP,
    ACTION_SWAP_IN_SINGLE,
    ACTION_SETTLE_ALL,
    ACTION_TAKE_ALL
} from "../../integrations/uniswap/IUniswapUniversalRouter.sol";
import {IUniswapV4Gateway} from "../../interfaces/uniswap/IUniswapV4Gateway.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "@gearbox-protocol/core-v3/contracts/interfaces/external/IWETH.sol";

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

/// @title UniswapV4Gateway
/// @dev This is connector contract to allow Gearbox adapters to swap through the Balancer V3 Router.
///      Since the router requires the caller to approve inputs in Permit2, we need an intermediate contract,
///      which will be approved to spend the inputs and then call the Permit2 and the router.
contract UniswapV4Gateway is IUniswapV4Gateway, IVersion {
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::UNISWAP_V4";
    uint256 public constant override version = 3_10;

    address public immutable universalRouter;
    address public immutable poolManager;
    address public immutable permit2;
    address public immutable weth;

    constructor(address _universalRouter, address _permit2, address _weth) {
        universalRouter = _universalRouter;
        poolManager = IUniversalRouter(_universalRouter).poolManager();
        permit2 = _permit2;
        weth = _weth;
    }

    function swapExactInputSingle(
        PoolKey calldata poolKey,
        bool zeroForOne,
        uint128 amountIn,
        uint128 amountOutMinimum,
        bytes calldata hookData
    ) external returns (uint256 amountOut) {
        address tokenIn = zeroForOne ? poolKey.token0 : poolKey.token1;
        address tokenOut = zeroForOne ? poolKey.token1 : poolKey.token0;

        amountIn = uint128(_transferIn(tokenIn, msg.sender, amountIn));

        (bytes memory commands, bytes[] memory inputs) =
            _getInputData(poolKey, zeroForOne, amountIn, amountOutMinimum, hookData);

        amountOut = _swap(commands, inputs, tokenIn, tokenOut, amountIn);

        _transferOut(tokenOut, msg.sender, amountOut);
    }

    function _swap(bytes memory commands, bytes[] memory inputs, address tokenIn, address tokenOut, uint128 amountIn)
        internal
        returns (uint256 amountOut)
    {
        if (tokenIn == address(0)) {
            uint256 balanceBefore = _getBalance(tokenOut);
            IUniversalRouter(universalRouter).execute{value: amountIn}(commands, inputs);
            amountOut = _getBalance(tokenOut) - balanceBefore;
        } else {
            IERC20(tokenIn).forceApprove(permit2, amountIn);
            IPermit2(permit2).approve(address(tokenIn), universalRouter, uint160(amountIn), uint48(block.timestamp));

            uint256 balanceBefore = _getBalance(tokenOut);
            IUniversalRouter(universalRouter).execute(commands, inputs);
            amountOut = _getBalance(tokenOut) - balanceBefore;
        }
    }

    function _getInputData(
        PoolKey memory poolKey,
        bool zeroForOne,
        uint128 amountIn,
        uint128 amountOutMinimum,
        bytes calldata hookData
    ) internal pure returns (bytes memory commands, bytes[] memory inputs) {
        commands = abi.encodePacked(uint8(COMMAND_V4_SWAP));

        inputs = new bytes[](1);
        bytes memory actions =
            abi.encodePacked(uint8(ACTION_SWAP_IN_SINGLE), uint8(ACTION_SETTLE_ALL), uint8(ACTION_TAKE_ALL));

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            UniswapV4ExactInputSingleParams({
                poolKey: poolKey,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                hookData: hookData
            })
        );

        params[1] = abi.encode(zeroForOne ? poolKey.token0 : poolKey.token1, amountIn);

        params[2] = abi.encode(zeroForOne ? poolKey.token1 : poolKey.token0, amountOutMinimum);

        inputs[0] = abi.encode(actions, params);
    }

    function _transferIn(address token, address from, uint256 amount) internal returns (uint256 transferredAmount) {
        if (token == address(0)) {
            uint256 balanceBefore = IERC20(weth).balanceOf(address(this));
            IERC20(weth).safeTransferFrom(from, address(this), amount);
            transferredAmount = IERC20(weth).balanceOf(address(this)) - balanceBefore;
            IWETH(weth).withdraw(transferredAmount);
        } else {
            uint256 balanceBefore = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransferFrom(from, address(this), amount);
            transferredAmount = IERC20(token).balanceOf(address(this)) - balanceBefore;
        }
        return transferredAmount;
    }

    function _getBalance(address token) internal view returns (uint256 balance) {
        if (token == address(0)) {
            return address(this).balance;
        } else {
            return IERC20(token).balanceOf(address(this));
        }
    }

    function _transferOut(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            IWETH(weth).deposit{value: amount}();
            IERC20(weth).safeTransfer(to, amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    receive() external payable {
        if (msg.sender != poolManager && msg.sender != weth) {
            revert UnexpectedETHTransferException();
        }
    }
}
