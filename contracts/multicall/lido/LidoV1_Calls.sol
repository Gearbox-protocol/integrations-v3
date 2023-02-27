// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import {ILidoV1Adapter} from "../../interfaces/lido/ILidoV1Adapter.sol";

interface LidoV1_Multicaller {}

library LidoV1_Calls {
    function submit(LidoV1_Multicaller c, uint256 amount) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(ILidoV1Adapter.submit, (amount))});
    }

    function submitAll(LidoV1_Multicaller c) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(ILidoV1Adapter.submitAll, ())});
    }
}
