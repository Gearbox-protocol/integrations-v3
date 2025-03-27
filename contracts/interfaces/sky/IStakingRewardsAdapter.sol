// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {IPhantomTokenWithdrawer} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

/// @title Staking Rewards Adapter Interface
interface IStakingRewardsAdapter is IAdapter, IPhantomTokenWithdrawer {
    error IncorrectStakedPhantomTokenException();

    function stakingToken() external view returns (address);

    function rewardsToken() external view returns (address);

    function stakedPhantomToken() external view returns (address);

    function stake(uint256 amount) external returns (bool useSafePrices);

    function stakeDiff(uint256 leftoverAmount) external returns (bool useSafePrices);

    function getReward() external returns (bool useSafePrices);

    function withdraw(uint256 amount) external returns (bool useSafePrices);

    function withdrawDiff(uint256 leftoverAmount) external returns (bool useSafePrices);
}
