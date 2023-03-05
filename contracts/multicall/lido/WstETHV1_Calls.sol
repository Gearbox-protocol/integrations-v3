// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import {IwstETHV1Adapter} from "../../interfaces/lido/IwstETHV1Adapter.sol";

interface WstETHV1_Multicaller {}

library WstETHV1_Calls {
    function wrap(WstETHV1_Multicaller c, uint256 amount) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IwstETHV1Adapter.wrap, (amount))});
    }

    function wrapAll(WstETHV1_Multicaller c) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IwstETHV1Adapter.wrapAll, ())});
    }

    function unwrap(WstETHV1_Multicaller c, uint256 amount) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IwstETHV1Adapter.unwrap, (amount))});
    }

    function unwrapAll(WstETHV1_Multicaller c) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IwstETHV1Adapter.unwrapAll, ())});
    }
}
