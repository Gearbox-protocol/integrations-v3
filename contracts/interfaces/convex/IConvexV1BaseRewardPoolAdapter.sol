// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";

/// @title Convex V1 BaseRewardPool adapter interface
interface IConvexV1BaseRewardPoolAdapter is IAdapter {
    function curveLPtoken() external view returns (address);

    function stakingToken() external view returns (address);

    function stakedPhantomToken() external view returns (address);

    function extraReward1() external view returns (address);

    function extraReward2() external view returns (address);

    function curveLPTokenMask() external view returns (uint256);

    function stakingTokenMask() external view returns (uint256);

    function stakedTokenMask() external view returns (uint256);

    function rewardTokensMask() external view returns (uint256);

    function stake(uint256) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function stakeAll() external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function getReward() external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdraw(uint256, bool claim) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdrawAll(bool claim) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdrawAndUnwrap(uint256, bool claim)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdrawAllAndUnwrap(bool claim) external returns (uint256 tokensToEnable, uint256 tokensToDisable);
}
