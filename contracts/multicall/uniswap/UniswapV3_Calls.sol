// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

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
                callData: abi.encodeWithSelector(
                    ISwapRouter.exactInputSingle.selector,
                    params
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
                callData: abi.encodeWithSelector(
                    IUniswapV3Adapter.exactAllInputSingle.selector,
                    params
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
                callData: abi.encodeWithSelector(
                    ISwapRouter.exactInput.selector,
                    params
                )
            });
    }

    function exactAllInput(
        UniswapV3_Multicaller c,
        IUniswapV3Adapter.ExactAllInputParams calldata params
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IUniswapV3Adapter.exactAllInput.selector,
                    params
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
                callData: abi.encodeWithSelector(
                    ISwapRouter.exactOutputSingle.selector,
                    params
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
                callData: abi.encodeWithSelector(
                    ISwapRouter.exactOutput.selector,
                    params
                )
            });
    }
}
