// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import {IAaveV2_LendingPoolAdapter} from "../../interfaces/aave/IAaveV2_LendingPoolAdapter.sol";

interface AaveV2_LendingPoolMulticaller {}

library AaveV2_LendingPoolCalls {
    function deposit(AaveV2_LendingPoolMulticaller c, address asset, uint256 amount, address, uint16)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IAaveV2_LendingPoolAdapter.deposit, (asset, amount, address(0), 0))
        });
    }

    function depositAll(AaveV2_LendingPoolMulticaller c, address asset) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IAaveV2_LendingPoolAdapter.depositAll, (asset))});
    }

    function withdraw(AaveV2_LendingPoolMulticaller c, address asset, uint256 amount, address)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IAaveV2_LendingPoolAdapter.withdraw, (asset, amount, address(0)))
        });
    }

    function withdrawAll(AaveV2_LendingPoolMulticaller c, address asset) internal pure returns (MultiCall memory) {
        return
            MultiCall({target: address(c), callData: abi.encodeCall(IAaveV2_LendingPoolAdapter.withdrawAll, (asset))});
    }
}
