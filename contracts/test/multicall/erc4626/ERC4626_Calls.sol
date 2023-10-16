// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import {IERC4626Adapter} from "../../../interfaces/erc4626/IERC4626Adapter.sol";

interface ERC4626_Multicaller {}

library ERC4626_Calls {
    function deposit(ERC4626_Multicaller c, uint256 assets, address) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IERC4626Adapter.deposit, (assets, address(0)))});
    }

    function depositAll(ERC4626_Multicaller c) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IERC4626Adapter.depositAll, ())});
    }

    function mint(ERC4626_Multicaller c, uint256 shares, address) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IERC4626Adapter.mint, (shares, address(0)))});
    }

    function withdraw(ERC4626_Multicaller c, uint256 assets, address, address)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IERC4626Adapter.withdraw, (assets, address(0), address(0)))
        });
    }

    function redeem(ERC4626_Multicaller c, uint256 shares, address, address) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IERC4626Adapter.redeem, (shares, address(0), address(0)))
        });
    }

    function redeemAll(ERC4626_Multicaller c) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IERC4626Adapter.redeemAll, ())});
    }
}
