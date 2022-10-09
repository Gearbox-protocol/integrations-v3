// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { MultiCall } from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import { IBooster } from "../../integrations/convex/IBooster.sol";

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
                callData: abi.encodeWithSelector(
                    IBooster.deposit.selector,
                    pid,
                    amount,
                    stake
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
                callData: abi.encodeWithSelector(
                    IBooster.depositAll.selector,
                    pid,
                    stake
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
                callData: abi.encodeWithSelector(
                    IBooster.withdraw.selector,
                    pid,
                    amount
                )
            });
    }

    function withdrawAll(ConvexV1_BoosterMulticaller c, uint256 pid)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IBooster.withdrawAll.selector,
                    pid
                )
            });
    }
}
