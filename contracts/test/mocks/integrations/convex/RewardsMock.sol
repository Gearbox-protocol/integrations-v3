// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

contract RewardsMock {
    address public rewardToken;

    constructor(address _rewardToken) {
        rewardToken = _rewardToken;
    }
}
