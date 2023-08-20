// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import {ICompoundV2_CTokenAdapter} from "../../../interfaces/compound/ICompoundV2_CTokenAdapter.sol";

interface CompoundV2_Multicaller {}

library CompoundV2_Calls {
    function mint(CompoundV2_Multicaller c, uint256 mintAmount) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(ICompoundV2_CTokenAdapter.mint, (mintAmount))});
    }

    function mintAll(CompoundV2_Multicaller c) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(ICompoundV2_CTokenAdapter.mintAll, ())});
    }

    function redeem(CompoundV2_Multicaller c, uint256 redeemTokens) internal pure returns (MultiCall memory) {
        return
            MultiCall({target: address(c), callData: abi.encodeCall(ICompoundV2_CTokenAdapter.redeem, (redeemTokens))});
    }

    function redeemAll(CompoundV2_Multicaller c) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(ICompoundV2_CTokenAdapter.redeemAll, ())});
    }

    function redeemUnderlying(CompoundV2_Multicaller c, uint256 redeemAmount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICompoundV2_CTokenAdapter.redeemUnderlying, (redeemAmount))
        });
    }
}
