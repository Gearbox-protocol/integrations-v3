// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { MultiCall } from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import { IwstETHV1Adapter } from "../../interfaces/adapters/lido/IwstETHV1Adapter.sol";

interface WstETHV1_Multicaller {}

library WstETHV1_Calls {
    function wrap(WstETHV1_Multicaller c, uint256 _stETHAmount)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IwstETHV1Adapter.wrap.selector,
                    _stETHAmount
                )
            });
    }

    function wrapAll(WstETHV1_Multicaller c)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IwstETHV1Adapter.wrapAll.selector
                )
            });
    }

    function unwrap(WstETHV1_Multicaller c, uint256 _wstETHAmount)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IwstETHV1Adapter.unwrap.selector,
                    _wstETHAmount
                )
            });
    }

    function unwrapAll(WstETHV1_Multicaller c)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IwstETHV1Adapter.unwrapAll.selector
                )
            });
    }
}
