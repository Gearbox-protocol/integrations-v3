// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import {IAaveV2_WrappedATokenAdapter} from "../../interfaces/aave/IAaveV2_WrappedATokenAdapter.sol";

interface AaveV2_WrappedATokenMulticaller {}

library AaveV2_WrappedATokenCalls {
    function deposit(AaveV2_WrappedATokenMulticaller c, uint256 assets) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IAaveV2_WrappedATokenAdapter.deposit, (assets))});
    }

    function depositAll(AaveV2_WrappedATokenMulticaller c) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IAaveV2_WrappedATokenAdapter.depositAll, ())});
    }

    function depositUnderlying(AaveV2_WrappedATokenMulticaller c, uint256 assets)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IAaveV2_WrappedATokenAdapter.depositUnderlying, (assets))
        });
    }

    function depositAllUnderlying(AaveV2_WrappedATokenMulticaller c) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IAaveV2_WrappedATokenAdapter.depositAllUnderlying, ())
        });
    }

    function withdraw(AaveV2_WrappedATokenMulticaller c, uint256 shares) internal pure returns (MultiCall memory) {
        return
            MultiCall({target: address(c), callData: abi.encodeCall(IAaveV2_WrappedATokenAdapter.withdraw, (shares))});
    }

    function withdrawAll(AaveV2_WrappedATokenMulticaller c) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IAaveV2_WrappedATokenAdapter.withdrawAll, ())});
    }

    function withdrawUnderlying(AaveV2_WrappedATokenMulticaller c, uint256 shares)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IAaveV2_WrappedATokenAdapter.withdrawUnderlying, (shares))
        });
    }

    function withdrawAllUnderlying(AaveV2_WrappedATokenMulticaller c) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IAaveV2_WrappedATokenAdapter.withdrawAllUnderlying, ())
        });
    }
}
