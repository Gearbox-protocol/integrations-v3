// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { MultiCall } from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import { IConvexV1BoosterAdapter } from "../../interfaces/convex/IConvexV1BoosterAdapter.sol";

interface ConvexV1_BoosterMulticaller {}

library ConvexV1_BoosterCalls {
    function deposit(
        ConvexV1_BoosterMulticaller c,
        uint256 pid,
        uint256 amount,
        bool stake
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeCall(
                    IConvexV1BoosterAdapter.deposit,
                    (pid, amount, stake)
                )
            });
    }

    function depositAll(
        ConvexV1_BoosterMulticaller c,
        uint256 pid,
        bool stake
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeCall(
                    IConvexV1BoosterAdapter.depositAll,
                    (pid, stake)
                )
            });
    }

    function withdraw(
        ConvexV1_BoosterMulticaller c,
        uint256 pid,
        uint256 amount
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeCall(
                    IConvexV1BoosterAdapter.withdraw,
                    (pid, amount)
                )
            });
    }

    function withdrawAll(
        ConvexV1_BoosterMulticaller c,
        uint256 pid
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeCall(
                    IConvexV1BoosterAdapter.withdrawAll,
                    (pid)
                )
            });
    }
}
