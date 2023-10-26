// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ConvexV1BoosterAdapter} from "../../../../adapters/convex/ConvexV1_Booster.sol";

contract ConvexV1BoosterAdapterHarness is ConvexV1BoosterAdapter {
    constructor(address _creditManager, address _booster) ConvexV1BoosterAdapter(_creditManager, _booster) {}

    function hackPidToPhantokToken(uint256 pid, address token) external {
        pidToPhantomToken[pid] = token;
    }
}
