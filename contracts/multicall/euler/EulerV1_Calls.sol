// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { MultiCall } from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import { IEulerV1_ETokenAdapter } from "../../interfaces/euler/IEulerV1_ETokenAdapter.sol";

interface EulerV1_Multicaller {}

library EulerV1_Calls {
    function deposit(
        EulerV1_Multicaller c,
        uint256,
        uint256 amount
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeCall(
                    IEulerV1_ETokenAdapter.deposit,
                    (0, amount)
                )
            });
    }

    function depositAll(
        EulerV1_Multicaller c
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeCall(IEulerV1_ETokenAdapter.depositAll, ())
            });
    }

    function withdraw(
        EulerV1_Multicaller c,
        uint256,
        uint256 amount
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeCall(
                    IEulerV1_ETokenAdapter.withdraw,
                    (0, amount)
                )
            });
    }

    function withdrawAll(
        EulerV1_Multicaller c
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeCall(IEulerV1_ETokenAdapter.withdrawAll, ())
            });
    }
}
