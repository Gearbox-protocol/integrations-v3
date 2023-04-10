// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IAdapterExceptions} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";
import {USER, CONFIGURATOR} from "@gearbox-protocol/core-v2/contracts/test/lib/constants.sol";

import {AaveV2_LendingPoolAdapter} from "../../../adapters/aave/AaveV2_LendingPoolAdapter.sol";

import {Tokens} from "../../config/Tokens.sol";

import {AaveTestHelper} from "./AaveTestHelper.sol";

/// @title Aave V2 lending pool adapter tests
/// @notice [AAV2LP]: Unit tests for Aave V2 lending pool adapter
contract AaveV2_LendingPoolAdapter_Test is AaveTestHelper {
    AaveV2_LendingPoolAdapter public adapter;

    function setUp() public {
        _setupAaveSuite(false);

        // create a lending pool adapter and add it to the credit manager
        evm.startPrank(CONFIGURATOR);
        adapter = new AaveV2_LendingPoolAdapter(address(creditManager), address(lendingPool));
        creditConfigurator.allowContract(address(lendingPool), address(adapter));
        evm.label(address(adapter), "LENDING_POOL_ADAPTER");
        evm.stopPrank();
    }

    /// @notice [AAV2LP-1]: All action functions revert if called not from the multicall
    function test_AAV2LP_01_action_functions_revert_if_called_not_from_multicall() public {
        evm.prank(USER);
        evm.expectRevert(IAdapterExceptions.CreditFacadeOnlyException.selector);
        adapter.deposit(dai, 1, address(0), 0);

        evm.prank(USER);
        evm.expectRevert(IAdapterExceptions.CreditFacadeOnlyException.selector);
        adapter.depositAll(dai);

        evm.prank(USER);
        evm.expectRevert(IAdapterExceptions.CreditFacadeOnlyException.selector);
        adapter.withdraw(dai, 1, address(0));

        evm.prank(USER);
        evm.expectRevert(IAdapterExceptions.CreditFacadeOnlyException.selector);
        adapter.withdrawAll(dai);
    }

    /// @notice [AAV2LP-2]: All action functions revert if called on not registered token
    function test_AAV2LP_02_action_functions_revert_if_called_on_not_registered_token() public {
        (address creditAccount, uint256 balance) = _openTestCreditAccount();
        tokenTestSuite.approve(dai, creditAccount, address(lendingPool), balance / 2);
        evm.prank(creditAccount);
        lendingPool.deposit(dai, balance / 2, creditAccount, 0);

        evm.expectRevert(IAdapterExceptions.TokenNotAllowedException.selector);
        executeOneLineMulticall(address(adapter), abi.encodeCall(adapter.deposit, (dai, balance / 2, address(0), 0)));

        evm.expectRevert(IAdapterExceptions.TokenNotAllowedException.selector);
        executeOneLineMulticall(address(adapter), abi.encodeCall(adapter.depositAll, (dai)));

        evm.expectRevert(IAdapterExceptions.TokenNotAllowedException.selector);
        executeOneLineMulticall(address(adapter), abi.encodeCall(adapter.withdraw, (dai, balance / 2, address(0))));

        evm.expectRevert(IAdapterExceptions.TokenNotAllowedException.selector);
        executeOneLineMulticall(address(adapter), abi.encodeCall(adapter.withdrawAll, (dai)));
    }

    /// @notice [AAV2LP-3]: `deposit` works correctly
    /// @dev Fuzzing time before deposit to see if adapter handles interest properly
    /// @dev Resulting aToken balance is allowed to deviate from the expected value by at most 1
    ///      due to rounding errors in rebalancing
    function test_AAV2LP_03_deposit_works_correctly(uint256 timedelta) public {
        evm.assume(timedelta < 3 * 365 days);
        uint256 snapshot = evm.snapshot();

        for (uint256 isUsdc; isUsdc < 2; ++isUsdc) {
            (address creditAccount, uint256 initialBalance) =
                _openAccountWithToken(isUsdc == 1 ? Tokens.USDC : Tokens.WETH);
            (address token, address aToken) = isUsdc == 1 ? (usdc, aUsdc) : (weth, aWeth);

            expectAllowance(token, creditAccount, address(lendingPool), 0);
            evm.warp(block.timestamp + timedelta);

            uint256 depositAmount = initialBalance / 2;

            bytes memory expectedCallData =
                abi.encodeCall(lendingPool.deposit, (token, depositAmount, creditAccount, 0));
            expectMulticallStackCalls(
                address(adapter), address(lendingPool), USER, expectedCallData, token, aToken, true
            );

            bytes memory callData = abi.encodeCall(adapter.deposit, (token, depositAmount, address(0), 0));
            executeOneLineMulticall(address(adapter), callData);

            expectBalance(token, creditAccount, initialBalance - depositAmount);
            // expectBalance(aToken, creditAccount, depositAmount);
            expectBalanceGe(aToken, creditAccount, depositAmount - 1, "");
            expectBalanceLe(aToken, creditAccount, depositAmount + 1, "");

            expectAllowance(token, creditAccount, address(lendingPool), 1);

            expectTokenIsEnabled(token, true);
            expectTokenIsEnabled(aToken, true);

            evm.revertTo(snapshot);
        }
    }

    /// @notice [AAV2LP-4]: `depositAll` works correctly
    /// @dev Fuzzing time before deposit to see if adapter handles interest properly
    /// @dev Resulting aToken balance is allowed to deviate from the expected value by at most 1
    ///      due to rounding errors in rebalancing
    function test_AAV2LP_04_depositAll_works_correctly(uint256 timedelta) public {
        evm.assume(timedelta < 3 * 365 days);
        uint256 snapshot = evm.snapshot();

        for (uint256 isUsdc; isUsdc < 2; ++isUsdc) {
            (address creditAccount, uint256 initialBalance) =
                _openAccountWithToken(isUsdc == 1 ? Tokens.USDC : Tokens.WETH);
            (address token, address aToken) = isUsdc == 1 ? (usdc, aUsdc) : (weth, aWeth);

            expectAllowance(token, creditAccount, address(lendingPool), 0);
            evm.warp(block.timestamp + timedelta);

            bytes memory expectedCallData =
                abi.encodeCall(lendingPool.deposit, (token, initialBalance - 1, creditAccount, 0));
            expectMulticallStackCalls(
                address(adapter), address(lendingPool), USER, expectedCallData, token, aToken, true
            );

            bytes memory callData = abi.encodeCall(adapter.depositAll, (token));
            executeOneLineMulticall(address(adapter), callData);

            expectBalance(token, creditAccount, 1);
            // expectBalance(aToken, creditAccount, initialBalance - 1);
            expectBalanceGe(aToken, creditAccount, initialBalance - 2, "");
            expectBalanceLe(aToken, creditAccount, initialBalance, "");

            expectAllowance(token, creditAccount, address(lendingPool), 1);

            expectTokenIsEnabled(token, false);
            expectTokenIsEnabled(aToken, true);

            evm.revertTo(snapshot);
        }
    }

    /// @notice [AAV2LP-5A]: `withdraw` works correctly
    /// @dev Fuzzing time before withdrawal to see if adapter handles interest properly
    /// @dev Resulting aToken balance is allowed to deviate from the expected value by at most 1
    ///      due to rounding errors in rebalancing
    function test_AAV2LP_05A_withdraw_works_correctly(uint256 timedelta) public {
        evm.assume(timedelta < 3 * 365 days);
        uint256 snapshot = evm.snapshot();

        for (uint256 isUsdc; isUsdc < 2; ++isUsdc) {
            (address token, address aToken) = isUsdc == 1 ? (usdc, aUsdc) : (weth, aWeth);
            (address creditAccount,) = _openAccountWithAToken(isUsdc == 1 ? Tokens.USDC : Tokens.WETH);

            evm.warp(block.timestamp + timedelta);
            uint256 initialBalance = tokenTestSuite.balanceOf(aToken, creditAccount);
            uint256 withdrawAmount = initialBalance / 2;

            bytes memory expectedCallData = abi.encodeCall(lendingPool.withdraw, (token, withdrawAmount, creditAccount));
            expectMulticallStackCalls(
                address(adapter), address(lendingPool), USER, expectedCallData, aToken, token, false
            );

            bytes memory callData = abi.encodeCall(adapter.withdraw, (token, withdrawAmount, creditAccount));
            executeOneLineMulticall(address(adapter), callData);

            expectBalance(token, creditAccount, withdrawAmount);
            // expectBalance(aToken, creditAccount, initialBalance - withdrawAmount);
            expectBalanceGe(aToken, creditAccount, initialBalance - withdrawAmount - 1, "");
            expectBalanceLe(aToken, creditAccount, initialBalance - withdrawAmount + 1, "");

            expectAllowance(aToken, creditAccount, address(lendingPool), 0);

            expectTokenIsEnabled(token, true);
            expectTokenIsEnabled(aToken, true);

            evm.revertTo(snapshot);
        }
    }

    /// @notice [AAV2LP-5B]: `withdraw` works correctly when `amount == type(uint256).max`
    /// @dev Fuzzing time before withdrawal to see if adapter handles interest properly
    /// @dev Resulting aToken balance is allowed to deviate from the expected value by at most 1
    ///      due to rounding errors in rebalancing
    function test_AAV2LP_05B_withdraw_works_correctly(uint256 timedelta) public {
        evm.assume(timedelta < 3 * 365 days);
        uint256 snapshot = evm.snapshot();

        for (uint256 isUsdc; isUsdc < 2; ++isUsdc) {
            (address token, address aToken) = isUsdc == 1 ? (usdc, aUsdc) : (weth, aWeth);
            (address creditAccount,) = _openAccountWithAToken(isUsdc == 1 ? Tokens.USDC : Tokens.WETH);

            evm.warp(block.timestamp + timedelta);
            uint256 initialBalance = tokenTestSuite.balanceOf(aToken, creditAccount);

            bytes memory expectedCallData =
                abi.encodeCall(lendingPool.withdraw, (token, initialBalance - 1, creditAccount));
            expectMulticallStackCalls(
                address(adapter), address(lendingPool), USER, expectedCallData, aToken, token, false
            );

            bytes memory callData = abi.encodeCall(adapter.withdraw, (token, type(uint256).max, creditAccount));
            executeOneLineMulticall(address(adapter), callData);

            expectBalance(token, creditAccount, initialBalance - 1);
            // expectBalance(aToken, creditAccount, 1);
            expectBalanceLe(aToken, creditAccount, 2, "");

            expectTokenIsEnabled(token, true);
            expectTokenIsEnabled(aToken, false);

            evm.revertTo(snapshot);
        }
    }

    /// @notice [AAV2LP-6]: `withdrawAll` works correctly
    /// @dev Fuzzing time before withdrawal to see if adapter handles interest properly
    /// @dev Resulting aToken balance is allowed to deviate from the expected value by at most 1
    ///      due to rounding errors in rebalancing
    function test_AAV2LP_06_withdrawAll_works_correctly(uint256 timedelta) public {
        evm.assume(timedelta < 3 * 365 days);
        uint256 snapshot = evm.snapshot();

        for (uint256 isUsdc; isUsdc < 2; ++isUsdc) {
            (address token, address aToken) = isUsdc == 1 ? (usdc, aUsdc) : (weth, aWeth);
            (address creditAccount,) = _openAccountWithAToken(isUsdc == 1 ? Tokens.USDC : Tokens.WETH);

            evm.warp(block.timestamp + timedelta);
            uint256 initialBalance = tokenTestSuite.balanceOf(aToken, creditAccount);

            bytes memory expectedCallData =
                abi.encodeCall(lendingPool.withdraw, (token, initialBalance - 1, creditAccount));
            expectMulticallStackCalls(
                address(adapter), address(lendingPool), USER, expectedCallData, aToken, token, false
            );

            bytes memory callData = abi.encodeCall(adapter.withdrawAll, (token));
            executeOneLineMulticall(address(adapter), callData);

            expectBalance(token, creditAccount, initialBalance - 1);
            // expectBalance(aToken, creditAccount, 1);
            expectBalanceLe(aToken, creditAccount, 2, "");

            expectTokenIsEnabled(token, true);
            expectTokenIsEnabled(aToken, false);

            evm.revertTo(snapshot);
        }
    }
}
