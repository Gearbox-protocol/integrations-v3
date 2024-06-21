// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023
pragma solidity ^0.8.23;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";

import {IwstETHV1Adapter} from "../../../interfaces/lido/IwstETHV1Adapter.sol";

interface WstETHV1_Multicaller {}

library WstETHV1_Calls {
    function wrap(WstETHV1_Multicaller c, uint256 amount) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IwstETHV1Adapter.wrap, (amount))});
    }

    function wrapDiff(WstETHV1_Multicaller c, uint256 leftoverAmount) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IwstETHV1Adapter.wrapDiff, (leftoverAmount))});
    }

    function unwrap(WstETHV1_Multicaller c, uint256 amount) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IwstETHV1Adapter.unwrap, (amount))});
    }

    function unwrapDiff(WstETHV1_Multicaller c, uint256 leftoverAmount) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IwstETHV1Adapter.unwrapDiff, (leftoverAmount))});
    }
}
