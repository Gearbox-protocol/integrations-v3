// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023
pragma solidity ^0.8.23;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IUniswapV2Adapter} from "../../../interfaces/uniswap/IUniswapV2Adapter.sol";

interface UniswapV2_Multicaller {}

library UniswapV2_Calls {
    function swapTokensForExactTokens(
        UniswapV2_Multicaller c,
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(
                IUniswapV2Adapter.swapTokensForExactTokens, (amountOut, amountInMax, path, address(0), deadline)
                )
        });
    }

    function swapExactTokensForTokens(
        UniswapV2_Multicaller c,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(
                IUniswapV2Adapter.swapExactTokensForTokens, (amountIn, amountOutMin, path, address(0), deadline)
                )
        });
    }

    function swapDiffTokensForTokens(
        UniswapV2_Multicaller c,
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        address[] memory path,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(
                IUniswapV2Adapter.swapDiffTokensForTokens, (leftoverAmount, rateMinRAY, path, deadline)
                )
        });
    }
}
