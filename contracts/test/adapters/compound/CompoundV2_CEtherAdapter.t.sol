// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {CONFIGURATOR} from "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

import {CompoundV2_CEtherAdapter} from "../../../adapters/compound/CompoundV2_CEtherAdapter.sol";

import {CompoundTestHelper} from "./CompoundTestHelper.sol";

/// @title Compound V2 CEther adapter test
/// @notice [ACV2CETH]: Unit tests for Compound V2 CEther adapter
contract CompoundV2_CEtherAdapter_Test is CompoundTestHelper {
    CompoundV2_CEtherAdapter adapter;

    function setUp() public {
        _setupCompoundSuite();

        evm.startPrank(CONFIGURATOR);
        adapter = new CompoundV2_CEtherAdapter(address(creditManager), address(gateway));
        creditConfigurator.allowContract(address(gateway), address(adapter));
        evm.label(address(adapter), "cETH_ADAPTER");
        evm.stopPrank();
    }

    /// @notice [ACV2CETH-1]: Constructor sets correct values
    function test_ACV2CETH_01_constructor_sets_correct_values() public {
        assertEq(adapter.underlying(), weth, "Incorrect WETH address");
        assertEq(adapter.cToken(), ceth, "Incorrect cETH address");
        assertEq(adapter.tokenMask(), creditManager.tokenMasksMap(weth), "Incorrect WETH mask");
        assertEq(adapter.cTokenMask(), creditManager.tokenMasksMap(ceth), "Incorrect cETH mask");
    }
}
