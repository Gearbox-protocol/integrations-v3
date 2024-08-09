// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024
pragma solidity ^0.8.23;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";

interface YearnV2_Multicaller {}

library YearnV2_Calls {
    function depositDiff(YearnV2_Multicaller c, uint256 leftoverAmount) internal pure returns (MultiCall memory) {
        return
            MultiCall({target: address(c), callData: abi.encodeWithSignature("depositDiff(uint256)", leftoverAmount)});
    }

    function deposit(YearnV2_Multicaller c, uint256 amount) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeWithSignature("deposit(uint256)", amount)});
    }

    function deposit(YearnV2_Multicaller c, uint256 amount, address) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeWithSignature("deposit(uint256,address)", amount, address(0))
        });
    }

    function withdrawDiff(YearnV2_Multicaller c, uint256 leftoverAmount) internal pure returns (MultiCall memory) {
        return
            MultiCall({target: address(c), callData: abi.encodeWithSignature("withdrawDiff(uint256)", leftoverAmount)});
    }

    function withdraw(YearnV2_Multicaller c, uint256 maxShares) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeWithSignature("withdraw(uint256)", maxShares)});
    }

    function withdraw(YearnV2_Multicaller c, uint256 maxShares, address) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeWithSignature("withdraw(uint256,address)", maxShares, address(0))
        });
    }

    function withdraw(YearnV2_Multicaller c, uint256 maxShares, address, uint256 maxLoss)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeWithSignature("withdraw(uint256,address,uint256)", maxShares, address(0), maxLoss)
        });
    }
}
