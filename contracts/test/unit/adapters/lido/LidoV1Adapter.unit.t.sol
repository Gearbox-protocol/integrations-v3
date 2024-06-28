// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {LidoV1Adapter} from "../../../../adapters/lido/LidoV1.sol";
import {LidoV1Gateway} from "../../../../helpers/lido/LidoV1_WETHGateway.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Lido v1 adapter unit test
/// @notice U:[LDO1]: Unit tests for Lido v1 adapter
contract LidoV1AdapterUnitTest is AdapterUnitTestHelper {
    LidoV1Adapter adapter;

    address gateway;
    address treasury;

    address weth;
    address stETH;

    function setUp() public {
        _setUp();

        gateway = makeAddr("LIDO_GATEWAY");
        treasury = makeAddr("TREASURY");
        address pool = makeAddr("POOL");

        vm.mockCall(address(creditManager), abi.encodeWithSignature("pool()"), abi.encode(pool));
        vm.mockCall(pool, abi.encodeWithSignature("treasury()"), abi.encode(treasury));

        weth = tokens[0];
        stETH = tokens[1];

        vm.mockCall(gateway, abi.encodeWithSignature("weth()"), abi.encode(weth));
        vm.mockCall(gateway, abi.encodeWithSignature("stETH()"), abi.encode(stETH));

        adapter = new LidoV1Adapter(address(creditManager), gateway);
    }

    /// @notice U:[LDO1-1]: Constructor works as expected
    function test_U_LDO1_01_constructor_works_as_expected() public {
        _readsTokenMask(weth);
        _readsTokenMask(stETH);
        adapter = new LidoV1Adapter(address(creditManager), gateway);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), gateway, "Incorrect targetContract");
        assertEq(adapter.weth(), weth, "Incorrect weth");
        assertEq(adapter.stETH(), stETH, "Incorrect stETH");
        assertEq(adapter.treasury(), treasury, "Incorrect treasury");
    }

    /// @notice U:[LDO1-2]: Wrapper functions revert on wrong caller
    function test_U_LDO1_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.submit(0);

        _revertsOnNonFacadeCaller();
        adapter.submitDiff(0);
    }

    /// @notice U:[LDO1-3]: `submit` works as expected
    function test_U_LDO1_03_submit_works_as_expected() public {
        _executesSwap({
            tokenIn: weth,
            callData: abi.encodeCall(LidoV1Gateway.submit, (1000, treasury)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.submit(1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[LDO1-4]: `submitDiff` works as expected
    function test_U_LDO1_04_submitDiff_works_as_expected() public diffTestCases {
        deal({token: weth, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: weth,
            callData: abi.encodeCall(LidoV1Gateway.submit, (diffInputAmount, treasury)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.submitDiff(diffLeftoverAmount);
        assertFalse(useSafePrices);
    }
}
