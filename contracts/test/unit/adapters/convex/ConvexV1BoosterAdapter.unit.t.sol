// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {BoosterMock} from "../../../mocks/integrations/convex/BoosterMock.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {ConvexV1BoosterAdapterHarness} from "./ConvexV1BoosterAdapter.harness.sol";
import {IConvexV1BoosterAdapter} from "../../../../interfaces/convex/IConvexV1BoosterAdapter.sol";

/// @title Convex v1 booster adapter unit test
/// @notice U:[CVX1B]: Unit tests for Convex v1 booster adapter
contract ConvexV1BoosterAdapterUnitTest is AdapterUnitTestHelper {
    ConvexV1BoosterAdapterHarness adapter;
    BoosterMock booster;

    function setUp() public {
        _setUp();

        booster = new BoosterMock(address(0));
        booster.setPoolInfo(42, tokens[0], tokens[1]);

        adapter = new ConvexV1BoosterAdapterHarness(address(creditManager), address(booster));
        adapter.hackSupportedPids(42);
        adapter.hackPidMappings(42, tokens[2], tokens[0], tokens[1]);
    }

    /// @notice U:[CVX1B-1]: Constructor works as expected
    function test_U_CVX1B_01_constructor_works_as_expected() public view {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), address(booster), "Incorrect targetContract");
    }

    /// @notice U:[CVX1B-2]: Wrapper functions revert on wrong caller
    function test_U_CVX1B_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.deposit(0, 0, false);

        _revertsOnNonFacadeCaller();
        adapter.depositDiff(0, 0, false);

        _revertsOnNonFacadeCaller();
        adapter.withdraw(0, 0);

        _revertsOnNonFacadeCaller();
        adapter.withdrawDiff(0, 0);
    }

    /// @notice U:[CVX1B-2A]: Functions revert on unknown pid
    function test_U_CVX1B_02A_functions_revert_on_unknown_pid() public {
        vm.expectRevert(IConvexV1BoosterAdapter.UnsupportedPidException.selector);
        vm.prank(creditFacade);
        adapter.deposit(90, 0, false);

        vm.expectRevert(IConvexV1BoosterAdapter.UnsupportedPidException.selector);
        vm.prank(creditFacade);
        adapter.depositDiff(90, 0, false);

        vm.expectRevert(IConvexV1BoosterAdapter.UnsupportedPidException.selector);
        vm.prank(creditFacade);
        adapter.withdraw(90, 0);

        vm.expectRevert(IConvexV1BoosterAdapter.UnsupportedPidException.selector);
        vm.prank(creditFacade);
        adapter.withdrawDiff(90, 0);
    }

    /// @notice U:[CVX1B-3]: `deposit` works as expected
    function test_U_CVX1B_03_deposit_works_as_expected() public {
        for (uint256 i; i < 2; ++i) {
            bool stake = i == 1;

            _executesSwap({
                tokenIn: tokens[0],
                callData: abi.encodeCall(adapter.deposit, (42, 1000, stake)),
                requiresApproval: true
            });

            vm.prank(creditFacade);
            bool useSafePrices = adapter.deposit(42, 1000, stake);
            assertFalse(useSafePrices);
        }
    }

    /// @notice U:[CVX1B-4]: `depositDiff` works as expected
    function test_U_CVX1B_04_depositDiff_works_as_expected() public diffTestCases {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});
        for (uint256 i; i < 2; ++i) {
            bool stake = i == 1;
            _readsActiveAccount();
            _executesSwap({
                tokenIn: tokens[0],
                callData: abi.encodeCall(adapter.deposit, (42, diffInputAmount, stake)),
                requiresApproval: true
            });

            vm.prank(creditFacade);
            bool useSafePrices = adapter.depositDiff(42, diffLeftoverAmount, stake);

            assertFalse(useSafePrices);
        }
    }

    /// @notice U:[CVX1B-5]: `withdraw` works as expected
    function test_U_CVX1B_05_withdraw_works_as_expected() public {
        _executesSwap({
            tokenIn: tokens[1],
            callData: abi.encodeCall(adapter.withdraw, (42, 1000)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdraw(42, 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[CVX1B-6]: `withdrawDiff` works as expected
    function test_U_CVX1B_06_withdrawDiff_works_as_expected() public diffTestCases {
        deal({token: tokens[1], to: creditAccount, give: diffMintedAmount});
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[1],
            callData: abi.encodeCall(adapter.withdraw, (42, diffInputAmount)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawDiff(42, diffLeftoverAmount);
        assertFalse(useSafePrices);
    }

    /// @notice U:[CVX1B-7]: `updatedStakedPhantomTokensMap` reverts on wrong caller
    function test_U_CVX1B_07_updateStakedPhantomTokensMap_reverts_on_wrong_caller() public {
        _revertsOnNonConfiguratorCaller();
        adapter.updateSupportedPids();
    }
}
