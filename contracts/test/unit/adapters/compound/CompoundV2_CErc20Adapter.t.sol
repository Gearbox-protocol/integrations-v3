// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {CONFIGURATOR} from "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";
import {CompoundV2_CErc20Adapter} from "../../../../adapters/compound/CompoundV2_CErc20Adapter.sol";
import {CompoundTestHelper} from "./CompoundTestHelper.sol";
import "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Compound V2 CErc20 adapter test
/// @notice [ACV2CERC]: Unit tests for Compound V2 CErc20 adapter
contract CompoundV2_CErc20Adapter_Test is CompoundTestHelper {
    CompoundV2_CErc20Adapter adapter;

    function setUp() public {
        _setupCompoundSuite();

        vm.startPrank(CONFIGURATOR);
        adapter = new CompoundV2_CErc20Adapter(address(creditManager), cusdc);
        creditConfigurator.allowAdapter(address(adapter));
        vm.label(address(adapter), "cUSDC_ADAPTER");
        vm.stopPrank();
    }

    /// @notice [ACV2CERC-1]: Constructor reverts on not registered tokens
    function test_ACV2CERC_01_constructor_reverts_on_not_registered_tokens() public {
        vm.expectRevert(TokenNotAllowedException.selector);
        new CompoundV2_CErc20Adapter(address(creditManager), cdai);
    }

    /// @notice [ACV2CERC-2]: Constructor sets correct values
    function test_ACV2CERC_02_constructor_sets_correct_values() public {
        assertEq(adapter.underlying(), usdc, "Incorrect USDC address");
        assertEq(adapter.cToken(), cusdc, "Incorrect cUSDC address");
        assertEq(adapter.tokenMask(), creditManager.getTokenMaskOrRevert(usdc), "Incorrect USDC mask");
        assertEq(adapter.cTokenMask(), creditManager.getTokenMaskOrRevert(cusdc), "Incorrect cUSDC mask");
    }
}
