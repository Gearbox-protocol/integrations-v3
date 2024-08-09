// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024
pragma solidity ^0.8.23;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICamelotV3Router} from "../../../integrations/camelot/ICamelotV3Router.sol";
import {ICamelotV3Adapter} from "../../../interfaces/camelot/ICamelotV3Adapter.sol";

interface CamelotV3_Multicaller {}

library CamelotV3_Calls {
    function exactInputSingle(CamelotV3_Multicaller c, ICamelotV3Router.ExactInputSingleParams memory params)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({target: address(c), callData: abi.encodeCall(ICamelotV3Adapter.exactInputSingle, (params))});
    }

    function exactInputSingleSupportingFeeOnTransferTokens(
        CamelotV3_Multicaller c,
        ICamelotV3Router.ExactInputSingleParams memory params
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICamelotV3Adapter.exactInputSingleSupportingFeeOnTransferTokens, (params))
        });
    }

    function exactDiffInputSingle(CamelotV3_Multicaller c, ICamelotV3Adapter.ExactDiffInputSingleParams memory params)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({target: address(c), callData: abi.encodeCall(ICamelotV3Adapter.exactDiffInputSingle, (params))});
    }

    function exactDiffInputSingleSupportingFeeOnTransferTokens(
        CamelotV3_Multicaller c,
        ICamelotV3Adapter.ExactDiffInputSingleParams memory params
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICamelotV3Adapter.exactDiffInputSingleSupportingFeeOnTransferTokens, (params))
        });
    }

    function exactInput(CamelotV3_Multicaller c, ICamelotV3Router.ExactInputParams memory params)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({target: address(c), callData: abi.encodeCall(ICamelotV3Adapter.exactInput, (params))});
    }

    function exactDiffInput(CamelotV3_Multicaller c, ICamelotV3Adapter.ExactDiffInputParams memory params)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({target: address(c), callData: abi.encodeCall(ICamelotV3Adapter.exactDiffInput, (params))});
    }

    function exactOutputSingle(CamelotV3_Multicaller c, ICamelotV3Router.ExactOutputSingleParams memory params)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({target: address(c), callData: abi.encodeCall(ICamelotV3Adapter.exactOutputSingle, (params))});
    }

    function exactOutput(CamelotV3_Multicaller c, ICamelotV3Router.ExactOutputParams memory params)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({target: address(c), callData: abi.encodeCall(ICamelotV3Adapter.exactOutput, (params))});
    }
}
