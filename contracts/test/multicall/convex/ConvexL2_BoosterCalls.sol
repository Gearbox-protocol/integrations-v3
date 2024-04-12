// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import {IConvexL2BoosterAdapter} from "../../../interfaces/convex/IConvexL2BoosterAdapter.sol";

interface ConvexL2_BoosterMulticaller {}

library ConvexL2_BoosterCalls {
    function deposit(ConvexL2_BoosterMulticaller c, uint256 pid, uint256 amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({target: address(c), callData: abi.encodeCall(IConvexL2BoosterAdapter.deposit, (pid, amount))});
    }

    function depositDiff(ConvexL2_BoosterMulticaller c, uint256 pid, uint256 leftoverAmount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IConvexL2BoosterAdapter.depositDiff, (pid, leftoverAmount))
        });
    }
}
