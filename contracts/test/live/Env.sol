// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {LiveTestHelper} from "../suites/LiveTestHelper.sol";
// import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_LidoEquivalenceTest is LiveTestHelper {
    function test_tt() public liveCreditTest("dUSDC") {}
}
