// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024
pragma solidity ^0.8.23;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IDaiUsdsAdapter} from "../../../interfaces/sky/IDaiUsdsAdapter.sol";

interface DaiUsds_Multicaller {}

library DaiUsds_Calls {
    function daiToUsds(DaiUsds_Multicaller c, address usr, uint256 wad) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IDaiUsdsAdapter.daiToUsds, (usr, wad))});
    }

    function daiToUsdsDiff(DaiUsds_Multicaller c, uint256 leftoverAmount) internal pure returns (MultiCall memory) {
        return
            MultiCall({target: address(c), callData: abi.encodeCall(IDaiUsdsAdapter.daiToUsdsDiff, (leftoverAmount))});
    }

    function usdsToDai(DaiUsds_Multicaller c, address usr, uint256 wad) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IDaiUsdsAdapter.usdsToDai, (usr, wad))});
    }

    function usdsToDaiDiff(DaiUsds_Multicaller c, uint256 leftoverAmount) internal pure returns (MultiCall memory) {
        return
            MultiCall({target: address(c), callData: abi.encodeCall(IDaiUsdsAdapter.usdsToDaiDiff, (leftoverAmount))});
    }
}
