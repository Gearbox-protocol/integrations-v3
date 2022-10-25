// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { MultiCall } from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import { IUniswapV2Router02 } from "../../integrations/uniswap/IUniswapV2Router02.sol";
import { IUniswapV2Adapter } from "../../interfaces/adapters/uniswap/IUniswapV2Adapter.sol";

interface UniswapV2_Multicaller {}

library UniswapV2_Calls {
    function swapTokensForExactTokens(
        UniswapV2_Multicaller c,
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address recipient,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IUniswapV2Router02.swapTokensForExactTokens.selector,
                    amountOut,
                    amountInMax,
                    path,
                    recipient,
                    deadline
                )
            });
    }

    function swapExactTokensForTokens(
        UniswapV2_Multicaller c,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address recipient,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IUniswapV2Router02.swapExactTokensForTokens.selector,
                    amountIn,
                    amountOutMin,
                    path,
                    recipient,
                    deadline
                )
            });
    }

    function swapAllTokensForTokens(
        UniswapV2_Multicaller c,
        uint256 rateMinRAY,
        address[] calldata path,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IUniswapV2Adapter.swapAllTokensForTokens.selector,
                    rateMinRAY,
                    path,
                    deadline
                )
            });
    }
}
