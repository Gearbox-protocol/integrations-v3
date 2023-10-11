// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {AP_TREASURY} from "@gearbox-protocol/core-v3/contracts/interfaces/IAddressProviderV3.sol";
import {LidoV1Adapter} from "../../../../adapters/lido/LidoV1.sol";
import {LidoV1Gateway} from "../../../../helpers/lido/LidoV1_WETHGateway.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Lido v1 adapter unit test
/// @notice U:[LDO]: Unit tests for Lido v1 adapter
contract LidoV1AdapterUnitTest is AdapterUnitTestHelper {
    LidoV1Adapter adapter;

    address gateway;
    address treasury;

    address weth;
    address stETH;

    uint256 wethMask;
    uint256 stETHMask;

    function setUp() public {
        _setUp();

        gateway = makeAddr("LIDO_GATEWAY");
        treasury = makeAddr("TREASURY");

        vm.prank(configurator);
        addressProvider.setAddress(AP_TREASURY, treasury, false);

        (weth, wethMask) = (tokens[0], 1);
        (stETH, stETHMask) = (tokens[1], 2);

        vm.mockCall(gateway, abi.encodeWithSignature("weth()"), abi.encode(weth));
        vm.mockCall(gateway, abi.encodeWithSignature("stETH()"), abi.encode(stETH));

        adapter = new LidoV1Adapter(address(creditManager), gateway);
    }

    /// @notice U:[LDO-1]: Constructor works as expected
    function test_U_LDO_01_constructor_works_as_expected() public {
        _readsTokenMask(weth);
        _readsTokenMask(stETH);
        adapter = new LidoV1Adapter(address(creditManager), gateway);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.addressProvider(), address(addressProvider), "Incorrect addressProvider");
        assertEq(adapter.targetContract(), gateway, "Incorrect targetContract");
        assertEq(adapter.weth(), weth, "Incorrect weth");
        assertEq(adapter.stETH(), stETH, "Incorrect stETH");
        assertEq(adapter.wethTokenMask(), wethMask, "Incorrect wethMask");
        assertEq(adapter.stETHTokenMask(), stETHMask, "Incorrect stETHMask");
        assertEq(adapter.treasury(), treasury, "Incorrect treasury");
    }

    /// @notice U:[LDO-2]: Wrapper functions revert on wrong caller
    function test_U_LDO_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.submit(0);

        _revertsOnNonFacadeCaller();
        adapter.submitAll();
    }

    /// @notice U:[LDO-3]: `submit` works as expected
    function test_U_LDO_03_submit_works_as_expected() public {
        _executesSwap({
            tokenIn: weth,
            tokenOut: stETH,
            callData: abi.encodeCall(LidoV1Gateway.submit, (1000, treasury)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.submit(1000);

        assertEq(tokensToEnable, stETHMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[LDO-4]: `submitAll` works as expected
    function test_U_LDO_04_submitAll_works_as_expected() public {
        deal({token: weth, to: creditAccount, give: 1000});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: weth,
            tokenOut: stETH,
            callData: abi.encodeCall(LidoV1Gateway.submit, (999, treasury)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.submitAll();

        assertEq(tokensToEnable, stETHMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, wethMask, "Incorrect tokensToDisable");
    }
}
