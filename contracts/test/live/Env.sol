// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {LiveTestHelper} from "../suites/LiveTestHelper.sol";

import {CONFIG_MAINNET_USDC_MT_V3} from "../config/USDC_MT_config.sol";
import {CONFIG_MAINNET_WBTC_MT_V3} from "../config/WBTC_MT_config.sol";
import {CONFIG_MAINNET_WETH_MT_V3} from "../config/WETH_MT_config.sol";

import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";
import "forge-std/console.sol";

contract Live_LidoEquivalenceTest is LiveTestHelper {
    function setUp() public {
        addDeployConfig(new CONFIG_MAINNET_USDC_MT_V3());
        addDeployConfig(new CONFIG_MAINNET_WBTC_MT_V3());
        addDeployConfig(new CONFIG_MAINNET_WETH_MT_V3());
    }

    function test_tt() public liveCreditTest("mainnet-usdc-mt-v3") {}
}
