// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {ZircuitPoolAdapterHarness} from "./ZircuitPoolAdapter.harness.sol";
import {IZircuitPoolAdapter} from "../../../../interfaces/zircuit/IZircuitPoolAdapter.sol";
import {IZircuitPool} from "../../../../integrations/zircuit/IZircuitPool.sol";
import {GeneralMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/GeneralMock.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Zircuit adapter unit test
contract ZircuitPoolAdapterUnitTest is AdapterUnitTestHelper {
    ZircuitPoolAdapterHarness adapter;
    GeneralMock zircuitMock;

    address depositToken;
    address phantomToken;

    function setUp() public {
        _setUp();

        depositToken = tokens[0];
        phantomToken = tokens[1];

        zircuitMock = new GeneralMock();
        adapter = new ZircuitPoolAdapterHarness(address(creditManager), address(zircuitMock));

        adapter.hackTokenToPhantomToken(depositToken, phantomToken);
        adapter.hackSupportedUnderlyings(depositToken);
    }

    /// @notice U:[ZIR-1]: functions revert on wrong caller
    function test_U_ZIR_01_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.depositFor(address(1), address(1), 1);

        _revertsOnNonFacadeCaller();
        adapter.depositDiff(address(1), 1);

        _revertsOnNonFacadeCaller();
        adapter.withdraw(address(1), 1);

        _revertsOnNonFacadeCaller();
        adapter.withdrawDiff(address(1), 1);

        _revertsOnNonConfiguratorCaller();
        adapter.updateSupportedUnderlyings();
    }

    /// @notice U:[ZIR-1A]: functions revert on unsupported token
    function test_U_ZIR_01A_functions_revert_on_unsupported_token() public {
        vm.expectRevert(IZircuitPoolAdapter.UnsupportedUnderlyingException.selector);
        vm.prank(creditFacade);
        adapter.depositFor(address(1), address(1), 1);

        vm.expectRevert(IZircuitPoolAdapter.UnsupportedUnderlyingException.selector);
        vm.prank(creditFacade);
        adapter.depositDiff(address(1), 1);

        vm.expectRevert(IZircuitPoolAdapter.UnsupportedUnderlyingException.selector);
        vm.prank(creditFacade);
        adapter.withdraw(address(1), 1);

        vm.expectRevert(IZircuitPoolAdapter.UnsupportedUnderlyingException.selector);
        vm.prank(creditFacade);
        adapter.withdrawDiff(address(1), 1);
    }

    /// @notice U:[ZIR-2]: depositFor works correctly
    function test_U_ZIR_02_depositFor_works_correctly() public {
        _executesSwap({
            tokenIn: depositToken,
            callData: abi.encodeCall(IZircuitPool.depositFor, (depositToken, creditAccount, 1000)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositFor(depositToken, address(1), 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[ZIR-3]: depositDiff works correctly
    function test_U_ZIR_03_depositDiff_works_correctly() public {
        deal({token: depositToken, to: creditAccount, give: 10000});

        _executesSwap({
            tokenIn: depositToken,
            callData: abi.encodeCall(IZircuitPool.depositFor, (depositToken, creditAccount, 9000)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositDiff(depositToken, 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[ZIR-4]: withdraw works correctly
    function test_U_ZIR_04_withdraw_works_correctly() public {
        _executesSwap({
            tokenIn: phantomToken,
            callData: abi.encodeCall(IZircuitPool.withdraw, (depositToken, 1000)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdraw(depositToken, 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[ZIR-5]: withdrawDiff works correctly
    function test_U_ZIR_05_withdrawDiff_works_correctly() public {
        deal({token: phantomToken, to: creditAccount, give: 10000});

        _executesSwap({
            tokenIn: phantomToken,
            callData: abi.encodeCall(IZircuitPool.withdraw, (depositToken, 9000)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawDiff(depositToken, 1000);
        assertFalse(useSafePrices);
    }
}
