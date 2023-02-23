// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { MultiCall } from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import { ISwapRouter } from "../../integrations/uniswap/IUniswapV3.sol";
import { IUniswapV3Adapter } from "../../interfaces/uniswap/IUniswapV3Adapter.sol";

interface UniswapV3_Multicaller {}

library UniswapV3_Calls {
    function exactInputSingle(
        UniswapV3_Multicaller c,
        ISwapRouter.ExactInputSingleParams calldata params
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeCall(
                    IUniswapV3Adapter.exactInputSingle,
                    (params)
                )
            });
    }

    function exactAllInputSingle(
        UniswapV3_Multicaller c,
        IUniswapV3Adapter.ExactAllInputSingleParams calldata params
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeCall(
                    IUniswapV3Adapter.exactAllInputSingle,
                    (params)
                )
            });
    }

    function exactInput(
        UniswapV3_Multicaller c,
        ISwapRouter.ExactInputParams calldata params
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeCall(IUniswapV3Adapter.exactInput, (params))
            });
    }

    function exactAllInput(
        UniswapV3_Multicaller c,
        IUniswapV3Adapter.ExactAllInputParams calldata params
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeCall(
                    IUniswapV3Adapter.exactAllInput,
                    (params)
                )
            });
    }

    function exactOutputSingle(
        UniswapV3_Multicaller c,
        ISwapRouter.ExactOutputSingleParams calldata params
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeCall(
                    IUniswapV3Adapter.exactOutputSingle,
                    (params)
                )
            });
    }

    function exactOutput(
        UniswapV3_Multicaller c,
        ISwapRouter.ExactOutputParams calldata params
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeCall(
                    IUniswapV3Adapter.exactOutput,
                    (params)
                )
            });
    }
}
