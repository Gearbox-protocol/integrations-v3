// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023
pragma solidity ^0.8.23;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ISwapRouter} from "../../../integrations/uniswap/IUniswapV3.sol";
import {IUniswapV3Adapter} from "../../../interfaces/uniswap/IUniswapV3Adapter.sol";

interface UniswapV3_Multicaller {}

library UniswapV3_Calls {
    function exactInputSingle(UniswapV3_Multicaller c, ISwapRouter.ExactInputSingleParams memory params)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({target: address(c), callData: abi.encodeCall(IUniswapV3Adapter.exactInputSingle, (params))});
    }

    function exactDiffInputSingle(UniswapV3_Multicaller c, IUniswapV3Adapter.ExactDiffInputSingleParams memory params)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({target: address(c), callData: abi.encodeCall(IUniswapV3Adapter.exactDiffInputSingle, (params))});
    }

    function exactInput(UniswapV3_Multicaller c, ISwapRouter.ExactInputParams memory params)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({target: address(c), callData: abi.encodeCall(IUniswapV3Adapter.exactInput, (params))});
    }

    function exactDiffInput(UniswapV3_Multicaller c, IUniswapV3Adapter.ExactDiffInputParams memory params)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({target: address(c), callData: abi.encodeCall(IUniswapV3Adapter.exactDiffInput, (params))});
    }

    function exactOutputSingle(UniswapV3_Multicaller c, ISwapRouter.ExactOutputSingleParams memory params)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({target: address(c), callData: abi.encodeCall(IUniswapV3Adapter.exactOutputSingle, (params))});
    }

    function exactOutput(UniswapV3_Multicaller c, ISwapRouter.ExactOutputParams memory params)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({target: address(c), callData: abi.encodeCall(IUniswapV3Adapter.exactOutput, (params))});
    }
}
