// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {BoosterMock} from "../../../mocks/integrations/convex/BoosterMock.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {ConvexV1BoosterAdapterHarness} from "./ConvexV1BoosterAdapter.harness.sol";

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
        adapter.hackPidToPhantokToken(42, tokens[2]);
    }

    /// @notice U:[CVX1B-1]: Constructor works as expected
    function test_U_CVX1B_01_constructor_works_as_expected() public {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.addressProvider(), address(addressProvider), "Incorrect addressProvider");
        assertEq(adapter.targetContract(), address(booster), "Incorrect targetContract");
    }

    /// @notice U:[CVX1B-2]: Wrapper functions revert on wrong caller
    function test_U_CVX1B_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.deposit(0, 0, false);

        _revertsOnNonFacadeCaller();
        adapter.depositAll(0, false);

        _revertsOnNonFacadeCaller();
        adapter.withdraw(0, 0);

        _revertsOnNonFacadeCaller();
        adapter.withdrawAll(0);
    }

    /// @notice U:[CVX1B-3]: `deposit` works as expected
    function test_U_CVX1B_03_deposit_works_as_expected() public {
        for (uint256 i; i < 2; ++i) {
            bool stake = i == 1;

            _executesSwap({
                tokenIn: tokens[0],
                tokenOut: stake ? tokens[2] : tokens[1],
                callData: abi.encodeCall(adapter.deposit, (42, 1000, stake)),
                requiresApproval: true,
                validatesTokens: true
            });

            vm.prank(creditFacade);
            (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.deposit(42, 1000, stake);

            assertEq(tokensToEnable, stake ? 4 : 2, "Incorrect tokensToEnable");
            assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
        }
    }

    /// @notice U:[CVX1B-4]: `depositAll` works as expected
    function test_U_CVX1B_04_depositAll_works_as_expected() public {
        for (uint256 i; i < 2; ++i) {
            bool stake = i == 1;

            _executesSwap({
                tokenIn: tokens[0],
                tokenOut: stake ? tokens[2] : tokens[1],
                callData: abi.encodeCall(adapter.depositAll, (42, stake)),
                requiresApproval: true,
                validatesTokens: true
            });

            vm.prank(creditFacade);
            (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.depositAll(42, stake);

            assertEq(tokensToEnable, stake ? 4 : 2, "Incorrect tokensToEnable");
            assertEq(tokensToDisable, 1, "Incorrect tokensToDisable");
        }
    }

    /// @notice U:[CVX1B-5]: `withdraw` works as expected
    function test_U_CVX1B_05_withdraw_works_as_expected() public {
        _executesSwap({
            tokenIn: tokens[1],
            tokenOut: tokens[0],
            callData: abi.encodeCall(adapter.withdraw, (42, 1000)),
            requiresApproval: false,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdraw(42, 1000);

        assertEq(tokensToEnable, 1, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CVX1B-6]: `withdrawAll` works as expected
    function test_U_CVX1B_06_withdrawAll_works_as_expected() public {
        _executesSwap({
            tokenIn: tokens[1],
            tokenOut: tokens[0],
            callData: abi.encodeCall(adapter.withdrawAll, (42)),
            requiresApproval: false,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdrawAll(42);

        assertEq(tokensToEnable, 1, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 2, "Incorrect tokensToDisable");
    }

    /// @notice U:[CVX1B-7]: `updatedStakedPhantomTokensMap` reverts on wrong caller
    function test_U_CVX1B_07_updateStakedPhantomTokensMap_reverts_on_wrong_caller() public {
        _revertsOnNonConfiguratorCaller();
        adapter.updateStakedPhantomTokensMap();
    }
}
