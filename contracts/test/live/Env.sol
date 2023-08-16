// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {LiveTestHelper} from "../suites/LiveTestHelper.sol";
// import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";
import {CONFIG_MAINNET_DUSDC_V3_ROUTER} from "../config/USDC_router_config.sol";

contract Live_LidoEquivalenceTest is LiveTestHelper {
    function setUp() public {
        addDeployConfig(new CONFIG_MAINNET_DUSDC_V3_ROUTER());
    }

    function test_tt() public liveCreditTest("mainnet-dusdc-v3-router") {}
}
