// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";

import {IMellowVaultAdapter} from "../../../interfaces/mellow/IMellowVaultAdapter.sol";

interface MellowVault_Multicaller {}

library MellowVault_Calls {
    function deposit(
        MellowVault_Multicaller c,
        address to,
        uint256[] memory amounts,
        uint256 minLpAmount,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IMellowVaultAdapter.deposit, (to, amounts, minLpAmount, deadline))
        });
    }

    function depositOneAsset(
        MellowVault_Multicaller c,
        address asset,
        uint256 amount,
        uint256 minLpAmount,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IMellowVaultAdapter.depositOneAsset, (asset, amount, minLpAmount, deadline))
        });
    }

    function depositOneAssetDiff(
        MellowVault_Multicaller c,
        address asset,
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IMellowVaultAdapter.depositOneAssetDiff, (asset, leftoverAmount, rateMinRAY, deadline))
        });
    }
}
