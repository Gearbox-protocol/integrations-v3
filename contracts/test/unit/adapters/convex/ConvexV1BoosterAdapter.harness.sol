// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ConvexV1BoosterAdapter} from "../../../../adapters/convex/ConvexV1_Booster.sol";

contract ConvexV1BoosterAdapterHarness is ConvexV1BoosterAdapter {
    using EnumerableSet for EnumerableSet.UintSet;

    constructor(address _creditManager, address _booster) ConvexV1BoosterAdapter(_creditManager, _booster) {}

    function hackPidMappings(uint256 pid, address phantomToken, address curveToken, address convexToken) external {
        pidToPhantomToken[pid] = phantomToken;
        pidToCurveToken[pid] = curveToken;
        pidToConvexToken[pid] = convexToken;
    }

    function hackSupportedPids(uint256 pid) external {
        _supportedPids.add(pid);
    }
}
