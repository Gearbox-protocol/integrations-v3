// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import {IConvexV1BaseRewardPoolAdapter} from "../../../interfaces/convex/IConvexV1BaseRewardPoolAdapter.sol";

interface ConvexV1_BaseRewardPoolMulticaller {}

library ConvexV1_BaseRewardPoolCalls {
    function stake(ConvexV1_BaseRewardPoolMulticaller c, uint256 amount) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IConvexV1BaseRewardPoolAdapter.stake, (amount))});
    }

    function stakeAll(ConvexV1_BaseRewardPoolMulticaller c) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IConvexV1BaseRewardPoolAdapter.stakeAll, ())});
    }

    function withdraw(ConvexV1_BaseRewardPoolMulticaller c, uint256 amount, bool claim)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IConvexV1BaseRewardPoolAdapter.withdraw, (amount, claim))
        });
    }

    function withdrawAll(ConvexV1_BaseRewardPoolMulticaller c, bool claim) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IConvexV1BaseRewardPoolAdapter.withdrawAll, (claim))
        });
    }

    function withdrawAndUnwrap(ConvexV1_BaseRewardPoolMulticaller c, uint256 amount, bool claim)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IConvexV1BaseRewardPoolAdapter.withdrawAndUnwrap, (amount, claim))
        });
    }

    function withdrawAllAndUnwrap(ConvexV1_BaseRewardPoolMulticaller c, bool claim)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IConvexV1BaseRewardPoolAdapter.withdrawAllAndUnwrap, (claim))
        });
    }

    function getReward(ConvexV1_BaseRewardPoolMulticaller c) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IConvexV1BaseRewardPoolAdapter.getReward, ())});
    }
}
