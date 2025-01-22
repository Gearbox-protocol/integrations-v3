// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IStakingRewardsAdapter} from "../../../interfaces/sky/IStakingRewardsAdapter.sol";

interface StakingRewards_Multicaller {}

library StakingRewards_Calls {
    function stake(StakingRewards_Multicaller c, uint256 amount) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IStakingRewardsAdapter.stake, (amount))});
    }

    function stakeDiff(StakingRewards_Multicaller c, uint256 leftoverAmount) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IStakingRewardsAdapter.stakeDiff, (leftoverAmount))
        });
    }

    function getReward(StakingRewards_Multicaller c) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IStakingRewardsAdapter.getReward, ())});
    }

    function withdraw(StakingRewards_Multicaller c, uint256 amount) internal pure returns (MultiCall memory) {
        return MultiCall({target: address(c), callData: abi.encodeCall(IStakingRewardsAdapter.withdraw, (amount))});
    }

    function withdrawDiff(StakingRewards_Multicaller c, uint256 leftoverAmount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IStakingRewardsAdapter.withdrawDiff, (leftoverAmount))
        });
    }
}
