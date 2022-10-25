// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { MultiCall } from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import { ILidoV1Adapter } from "../../interfaces/lido/ILidoV1Adapter.sol";

interface LidoV1_Multicaller {}

library LidoV1_Calls {
    function submit(LidoV1_Multicaller c, uint256 amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ILidoV1Adapter.submit.selector,
                    amount
                )
            });
    }

    function submitAll(LidoV1_Multicaller c)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ILidoV1Adapter.submitAll.selector
                )
            });
    }
}
