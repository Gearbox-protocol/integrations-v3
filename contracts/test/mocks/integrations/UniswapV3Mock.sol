// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {Path} from "../../lib/Path.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISwapRouter} from "../../../integrations/uniswap/IUniswapV3.sol";
import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {Test} from "forge-std/Test.sol";

uint256 constant ADDR_SIZE = 20;
uint256 constant FEE_SIZE = 3;

contract UniswapV3Mock is ISwapRouter, Test {
    using SafeERC20 for IERC20;
    using Path for bytes;

    uint256 private constant FEE_MULTIPLIER = 997;

    mapping(address => mapping(address => mapping(uint24 => uint256))) public rates;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        _;
    }

    function setRate(address tokenFrom, address tokenTo, uint256 rate_RAY) external {
        setRate(tokenFrom, tokenTo, 3000, rate_RAY);
    }

    function setRate(address tokenFrom, address tokenTo, uint24 fee, uint256 rate_RAY) public {
        rates[tokenFrom][tokenTo][fee] = rate_RAY;
        rates[tokenTo][tokenFrom][fee] = (RAY * RAY) / rate_RAY;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        amountOut = quoteExactInputSingle(params.tokenIn, params.tokenOut, params.fee, params.amountIn, 0);

        require(amountOut >= params.amountOutMinimum, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        // tokenIN
        IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);

        // tokenOUT
        IERC20(params.tokenOut).safeTransfer(params.recipient, amountOut);
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountIn)
    {
        amountIn = quoteExactOutputSingle(params.tokenIn, params.tokenOut, params.fee, params.amountOut, 0);

        require(amountIn <= params.amountInMaximum, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        // tokenIN
        IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // tokenOUT
        IERC20(params.tokenOut).safeTransfer(params.recipient, params.amountOut);
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut) {
        (address tokenIn, address tokenOut) = _extractTokens(params.path);

        amountOut = quoteExactInput(params.path, params.amountIn);

        require(amountOut >= params.amountOutMinimum, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        // tokenIN
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);

        // tokenOUT
        IERC20(tokenOut).safeTransfer(params.recipient, amountOut);
    }

    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn) {
        (address tokenOut, address tokenIn) = _extractTokens(params.path);

        amountIn = quoteExactOutput(params.path, params.amountOut);

        require(amountIn <= params.amountInMaximum, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        // tokenIN
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // tokenOUT
        IERC20(tokenOut).safeTransfer(params.recipient, params.amountOut);
    }

    function quoteExactInput(bytes memory path, uint256 amountIn) public view returns (uint256 amountOut) {
        amountOut = amountIn;

        while (path.length >= ADDR_SIZE * 2 + FEE_SIZE) {
            (address tokenA, address tokenB, uint24 fee) = path.decodeFirstPool();

            uint256 rate = rates[tokenA][tokenB][fee];

            require(rate != 0, "UniswapV3Mock: Rate is not setup");
            amountOut = (((amountOut * rate) / RAY) * ((1_000_000 - uint256(fee)))) / (1_000_000);

            path = path.skipToken();
        }
    }

    function quoteExactInputSingle(address tokenIn, address tokenOut, uint24 fee, uint256 amountIn, uint160)
        public
        view
        returns (uint256 amountOut)
    {
        uint256 rate = rates[tokenIn][tokenOut][fee];

        require(rate != 0, "UniswapV3Mock: Rate is not setup");
        amountOut = (((amountIn * rate) / RAY) * ((1_000_000 - uint256(fee)))) / (1_000_000);
    }

    function quoteExactOutput(bytes memory path, uint256 amountOut) public view returns (uint256 amountIn) {
        amountIn = amountOut;

        while (path.length >= ADDR_SIZE * 2 + FEE_SIZE) {
            (address tokenA, address tokenB, uint24 fee) = path.decodeFirstPool();

            uint256 rate = rates[tokenB][tokenA][fee];

            require(rate != 0, "UniswapV3Mock: Rate is not setup");
            amountIn = (((amountIn * RAY) / rate) * (1_000_000)) / ((1_000_000 - uint256(fee)));

            path = path.skipToken();
        }
    }

    function quoteExactOutputSingle(address tokenIn, address tokenOut, uint24 fee, uint256 amountOut, uint160)
        public
        view
        returns (uint256 amountIn)
    {
        uint256 rate = rates[tokenIn][tokenOut][fee];

        require(rate != 0, "UniswapV3Mock: Rate is not setup");
        amountIn = (((amountOut * RAY) / rate) * (1_000_000)) / ((1_000_000 - uint256(fee)));
    }

    function _extractTokens(bytes memory path) internal pure returns (address tokenA, address tokenB) {
        (tokenA,,) = path.decodeFirstPool();

        while (path.hasMultiplePools()) {
            path = path.skipToken();
        }

        (, tokenB,) = path.decodeFirstPool();
    }
}
