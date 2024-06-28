// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IAdapter} from "../../interfaces/IAdapter.sol";

/// @title Convex V1 BaseRewardPool adapter interface
interface IConvexV1BaseRewardPoolAdapter is IAdapter {
    function curveLPtoken() external view returns (address);

    function stakingToken() external view returns (address);

    function stakedPhantomToken() external view returns (address);

    function extraReward1() external view returns (address);

    function extraReward2() external view returns (address);

    function extraReward3() external view returns (address);

    function extraReward4() external view returns (address);

    function stake(uint256) external returns (bool useSafePrices);

    function stakeDiff(uint256 leftoverAmount) external returns (bool useSafePrices);

    function getReward() external returns (bool useSafePrices);

    function withdraw(uint256, bool claim) external returns (bool useSafePrices);

    function withdrawDiff(uint256 leftoverAmount, bool claim) external returns (bool useSafePrices);

    function withdrawAndUnwrap(uint256, bool claim) external returns (bool useSafePrices);

    function withdrawDiffAndUnwrap(uint256 leftoverAmount, bool claim) external returns (bool useSafePrices);
}
