// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";

import {IAaveV2_WrappedATokenAdapter} from "../../../interfaces/aave/IAaveV2_WrappedATokenAdapter.sol";

interface AaveV2_WrappedATokenMulticaller {}

library AaveV2_WrappedATokenCalls {
    function deposit(AaveV2_WrappedATokenMulticaller c, uint256 assets) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IAaveV2_WrappedATokenAdapter.deposit, (assets))});
    }

    function depositDiff(AaveV2_WrappedATokenMulticaller c, uint256 leftoverAmount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IAaveV2_WrappedATokenAdapter.depositDiff, (leftoverAmount))
        });
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

    function depositDiffUnderlying(AaveV2_WrappedATokenMulticaller c, uint256 leftoverAmount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IAaveV2_WrappedATokenAdapter.depositDiffUnderlying, (leftoverAmount))
        });
    }

    function withdraw(AaveV2_WrappedATokenMulticaller c, uint256 shares) internal pure returns (MultiCall memory) {
        return
            MultiCall({target: address(c), callData: abi.encodeCall(IAaveV2_WrappedATokenAdapter.withdraw, (shares))});
    }

    function withdrawDiff(AaveV2_WrappedATokenMulticaller c, uint256 leftoverAmount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IAaveV2_WrappedATokenAdapter.withdrawDiff, (leftoverAmount))
        });
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

    function withdrawDiffUnderlying(AaveV2_WrappedATokenMulticaller c, uint256 leftoverAmount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IAaveV2_WrappedATokenAdapter.withdrawDiffUnderlying, (leftoverAmount))
        });
    }
}
