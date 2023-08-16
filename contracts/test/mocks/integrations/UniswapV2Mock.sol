// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IUniswapV2Router02} from "../../../integrations/uniswap/IUniswapV2Router02.sol";
import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

contract UniswapV2Mock is IUniswapV2Router02 {
    using SafeERC20 for IERC20;

    uint256 public constant FEE_MULTIPLIER = 997;

    mapping(address => mapping(address => uint256)) private _rates_RAY;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        _;
    }

    function setRate(address tokenFrom, address tokenTo, uint256 rate_RAY) external {
        _rates_RAY[tokenFrom][tokenTo] = rate_RAY;
        _rates_RAY[tokenTo][tokenFrom] = (RAY * RAY) / rate_RAY;
    }

    function getRate(address tokenIn, address tokenOut) public view returns (uint256 rate) {
        rate = _rates_RAY[tokenIn][tokenOut];
        if (rate == 0) {
            revert("Token pair not found");
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256[] memory) {
        uint256[] memory amounts = getAmountsOut(amountIn, path);

        uint256 amountOut = amounts[path.length - 1];
        require(amountOut >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        // tokenIN
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);

        // tokenOUT
        IERC20(path[path.length - 1]).safeTransfer(to, amountOut);

        return amounts;
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256[] memory) {
        // uint256 rate_RAY = getRate(path);
        // require(rate_RAY != 0, "UniswapMock: Rate is not setup");
        // // transfers
        uint256[] memory amounts = getAmountsIn(amountOut, path);

        uint256 amountIn = amounts[0];

        require(amountIn <= amountInMax, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");

        // tokenIN
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);

        // tokenOUT
        IERC20(path[path.length - 1]).safeTransfer(to, amountOut);

        return amounts;
    }

    //// OTHER STUFF
    //// ALL OTHER FUNCTION DO NOTHING

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address, // token,
        uint256, // liquidity,
        uint256, // amountTokenMin,
        uint256, // amountETHMin,
        address, // to,
        uint256 //deadline
    ) external pure override returns (uint256 amountETH) {}

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address, // token,
        uint256, // liquidity,
        uint256, // amountTokenMin,
        uint256, // amountETHMin,
        address, // to,
        uint256, // deadline,
        bool, // approveMax,
        uint8, // v,
        bytes32, // r,
        bytes32 // s
    ) external pure override returns (uint256 amountETH) {}

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256, // amountIn,
        uint256, // amountOutMin,
        address[] calldata, // path,
        address, // to,
        uint256 // deadline
    ) external pure override {}

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256, // amountOutMin,
        address[] calldata, // path,
        address, // to,
        uint256 // deadline
    ) external payable override {}

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256, // amountIn,
        uint256, // amountOutMin,
        address[] calldata, // path,
        address, // to,
        uint256 // deadline
    ) external pure override {}

    function swapExactETHForTokens(
        uint256, // amountOutMin,
        address[] calldata, // path,
        address, // to,
        uint256 // deadline
    ) external payable override returns (uint256[] memory amounts) {}

    function swapTokensForExactETH(
        uint256, // amountOut,
        uint256, // amountInMax,
        address[] calldata, // path,
        address, // to,
        uint256 // deadline
    ) external pure override returns (uint256[] memory amounts) {}

    function swapExactTokensForETH(
        uint256, // amountIn,
        uint256, // amountOutMin,
        address[] calldata, // path,
        address, // to,
        uint256 // deadline
    ) external pure override returns (uint256[] memory amounts) {}

    function swapETHForExactTokens(
        uint256, // amountOut,
        address[] calldata, // path,
        address, // to,
        uint256 // deadline
    ) external payable override returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](1);
        return amounts;
    }

    function quote(
        uint256, // amountA,
        uint256, // reserveA,
        uint256 // reserveB
    ) external pure override returns (uint256 amountB) {
        return 0;
    }

    function getAmountOut(
        uint256, // amountIn,
        uint256, // reserveIn,
        uint256 // reserveOut
    ) external pure override returns (uint256 amountOut) {
        return 0;
    }

    function getAmountIn(
        uint256, // amountOut,
        uint256, // reserveIn,
        uint256 // reserveOut
    ) external pure override returns (uint256 amountIn) {
        return 0;
    }

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        public
        view
        override
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "Incorrect path length");

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i = 1; i < path.length; i++) {
            uint256 rate_RAY = getRate(path[i - 1], path[i]);

            require(rate_RAY != 0, "UniswapMock: Rate is not setup");
            // transfers

            amounts[i] = (((amounts[i - 1] * rate_RAY) / RAY) * FEE_MULTIPLIER) / 1_000;
        }
    }

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        public
        view
        override
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "Incorrect path length");

        // transfers

        amounts = new uint256[](path.length);
        amounts[path.length - 1] = amountOut;

        for (uint256 i = path.length - 1; i > 0; i--) {
            uint256 rate_RAY = getRate(path[i - 1], path[i]);
            require(rate_RAY != 0, "UniswapMock: Rate is not setup");
            amounts[i - 1] = (((amounts[i] * RAY) / rate_RAY) * 1_000) / FEE_MULTIPLIER;
        }
    }

    function factory() external pure override returns (address) {}

    function WETH() external pure override returns (address) {}

    function addLiquidity(
        address, // tokenA,
        address, // tokenB,
        uint256, // amountADesired,
        uint256, // amountBDesired,
        uint256, // amountAMin,
        uint256, // amountBMin,
        address, // to,
        uint256 // deadline
    ) external pure override returns (uint256 amountA, uint256 amountB, uint256 liquidity) {}

    function addLiquidityETH(
        address, // token,
        uint256, // amountTokenDesired,
        uint256, // amountTokenMin,
        uint256, // amountETHMin,
        address, // to,
        uint256 // deadline
    ) external payable override returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {}

    function removeLiquidity(
        address, // tokenA,
        address, // tokenB,
        uint256, // liquidity,
        uint256, // amountAMin,
        uint256, // amountBMin,
        address, // to,
        uint256 // deadline
    ) external pure override returns (uint256 amountA, uint256 amountB) {}

    function removeLiquidityETH(
        address, // token,
        uint256, // liquidity,
        uint256, // amountTokenMin,
        uint256, // amountETHMin,
        address, // to,
        uint256 // deadline
    ) external pure override returns (uint256 amountToken, uint256 amountETH) {
        return (0, 0);
    }

    function removeLiquidityWithPermit(
        address, // tokenA,
        address, // tokenB,
        uint256, // liquidity,
        uint256, // amountAMin,
        uint256, // amountBMin,
        address, // to,
        uint256, // deadline,
        bool, // approveMax,
        uint8, // v,
        bytes32, // r,
        bytes32 // s
    ) external pure override returns (uint256 amountA, uint256 amountB) {
        return (0, 0);
    }

    function removeLiquidityETHWithPermit(
        address, // token,
        uint256, // liquidity,
        uint256, // amountTokenMin,
        uint256, // amountETHMin,
        address, // to,
        uint256, // deadline,
        bool, // approveMax,
        uint8, // v,
        bytes32, // r,
        bytes32 // s
    ) external pure override returns (uint256 amountToken, uint256 amountETH) {
        return (0, 0);
    }
}
