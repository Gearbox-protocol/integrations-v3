// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

interface IConvexV1BaseRewardPoolAdapter is IAdapter {
    /// @dev Returns the address of a Curve pool LP token
    ///      staked in the adapter's targer Convex pool
    function curveLPtoken() external view returns (address);

    /// @dev Returns the address of a phantom token tracking
    ///      a Credit Account's staked balance in a Convex
    ///      pool
    function stakedPhantomToken() external view returns (address);

    /// @dev Returns the address of the first extra reward token
    /// @notice address(0) if the Convex pool has no extra reward tokens
    function extraReward1() external view returns (address);

    /// @dev Returns the address of the second extra reward token
    /// @notice address(0) if the Convex pool has less than 2 extra reward tokens
    function extraReward2() external view returns (address);

    /// @dev Returns the address of CVX
    function cvx() external view returns (address);

    // @dev The pid of baseRewardPool
    function pid() external view returns (uint256);

    /// @dev Returns the token that is paid as a reward to stakers
    /// @notice This is always CRV
    function rewardToken() external view returns (address);

    /// @dev Returns the token that is staked in the pool
    function stakingToken() external view returns (address);

    function stake(uint256) external;

    function stakeAll() external;

    function withdraw(uint256, bool claim) external;

    function withdrawAll(bool claim) external;

    function withdrawAndUnwrap(uint256, bool claim) external;

    function withdrawAllAndUnwrap(bool claim) external;

    function getReward() external;
}
