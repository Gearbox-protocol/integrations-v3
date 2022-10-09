// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { MultiCall } from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import { IBaseRewardPool } from "../../integrations/convex/IBaseRewardPool.sol";

interface ConvexV1_BaseRewardPoolMulticaller {}

library ConvexV1_BaseRewardPoolCalls {
    function stake(ConvexV1_BaseRewardPoolMulticaller c, uint256 amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IBaseRewardPool.stake.selector,
                    amount
                )
            });
    }

    function stakeAll(ConvexV1_BaseRewardPoolMulticaller c)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IBaseRewardPool.stakeAll.selector
                )
            });
    }

    function withdraw(
        ConvexV1_BaseRewardPoolMulticaller c,
        uint256 amount,
        bool claim
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IBaseRewardPool.withdraw.selector,
                    amount,
                    claim
                )
            });
    }

    function withdrawAll(ConvexV1_BaseRewardPoolMulticaller c, bool claim)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IBaseRewardPool.withdrawAll.selector,
                    claim
                )
            });
    }

    function withdrawAndUnwrap(
        ConvexV1_BaseRewardPoolMulticaller c,
        uint256 amount,
        bool claim
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IBaseRewardPool.withdrawAndUnwrap.selector,
                    amount,
                    claim
                )
            });
    }

    function withdrawAllAndUnwrap(
        ConvexV1_BaseRewardPoolMulticaller c,
        bool claim
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    IBaseRewardPool.withdrawAllAndUnwrap.selector,
                    claim
                )
            });
    }

    function getReward(
        ConvexV1_BaseRewardPoolMulticaller c,
        address account,
        bool claimExtras
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSignature(
                    "getReward(address,bool)",
                    account,
                    claimExtras
                )
            });
    }

    function getReward(ConvexV1_BaseRewardPoolMulticaller c)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSignature("getReward()")
            });
    }
}
