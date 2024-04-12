// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import {IConvexL2RewardPoolAdapter} from "../../../interfaces/convex/IConvexL2RewardPoolAdapter.sol";

interface ConvexL2_RewardPoolMulticaller {}

library ConvexL2_RewardPoolCalls {
    function withdraw(ConvexL2_RewardPoolMulticaller c, uint256 amount, bool claim)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IConvexL2RewardPoolAdapter.withdraw, (amount, claim))
        });
    }

    function withdrawDiff(ConvexL2_RewardPoolMulticaller c, uint256 leftoverAmount, bool claim)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IConvexL2RewardPoolAdapter.withdrawDiff, (leftoverAmount, claim))
        });
    }

    function getReward(ConvexL2_RewardPoolMulticaller c) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IConvexL2RewardPoolAdapter.getReward, ())});
    }
}
