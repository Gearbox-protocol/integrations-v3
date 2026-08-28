// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

enum Version {
    V1,
    V2,
    V2_1,
    V2_2
}

struct Path {
    uint256[] pairBinSteps;
    Version[] versions;
    IERC20[] tokenPath;
}

interface ITraderJoeRouter {
    function getSwapOut(address lbPair, uint128 amountIn, bool swapForY)
        external
        view
        returns (uint128 amountInLeft, uint128 amountOut, uint128 fee);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Path memory path,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Path memory path,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut);
}
