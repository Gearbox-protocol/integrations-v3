// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";

/// @title Convex L2 RewardPool adapter interface
interface IConvexL2RewardPoolAdapter is IAdapter {
    function curveLPtoken() external view returns (address);

    function reward0() external view returns (address);

    function reward1() external view returns (address);

    function reward2() external view returns (address);

    function reward3() external view returns (address);

    function reward4() external view returns (address);

    function reward5() external view returns (address);

    function curveLPTokenMask() external view returns (uint256);

    function convexPoolTokenMask() external view returns (uint256);

    function rewardTokensMask() external view returns (uint256);

    function getReward() external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdraw(uint256, bool claim) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdrawDiff(uint256 leftoverAmount, bool claim)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);
}
