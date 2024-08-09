// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IBooster} from "../../../../integrations/convex/IBooster.sol";

contract BoosterMock {
    address public minter;

    mapping(uint256 => IBooster.PoolInfo) public poolInfo;

    constructor(address cvx) {
        minter = cvx;
    }

    function setPoolInfo(uint256 pid, address curveLPToken, address convexStakingToken) external {
        poolInfo[pid].lptoken = curveLPToken;
        poolInfo[pid].token = convexStakingToken;
    }
}
