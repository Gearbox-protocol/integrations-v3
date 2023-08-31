// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {USER, CONFIGURATOR} from "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

import {AaveV2_WrappedATokenAdapter} from "../../../../adapters/aave/AaveV2_WrappedATokenAdapter.sol";
import {WrappedAToken} from "../../../../helpers/aave/AaveV2_WrappedAToken.sol";
import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {AaveTestHelper} from "./AaveTestHelper.sol";

import "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Aave V2 wrapped aToken adapter tests
/// @notice [AAV2W]: Unit tests for Aave V2 wrapper aToken adapter
contract AaveV2_WrappedATokenAdapter_Test is AaveTestHelper {
    AaveV2_WrappedATokenAdapter public adapter;

    function setUp() public {
        _setupAaveSuite(true);

        vm.startPrank(CONFIGURATOR);
        adapter = new AaveV2_WrappedATokenAdapter(address(creditManager), waUsdc);
        creditConfigurator.allowAdapter(address(adapter));
        vm.label(address(adapter), "waUSDC_ADAPTER");
        vm.stopPrank();
    }

    /// @notice [AAV2W-1]: Constructor reverts on not registered tokens
    function test_AAV2W_01_constructor_reverts_on_not_registered_tokens() public {
        vm.expectRevert(TokenNotAllowedException.selector);
        new AaveV2_WrappedATokenAdapter(address(creditManager), waDai);
    }

    /// @notice [AAV2W-2]: Constructor sets correct values
    function test_AAV2W_02_constructor_sets_correct_values() public {
        assertEq(adapter.aToken(), aUsdc, "Incorrect aUSDC address");
        assertEq(adapter.underlying(), usdc, "Incorrect USDC address");
        assertEq(adapter.waTokenMask(), creditManager.getTokenMaskOrRevert(waUsdc), "Incorrect waUSDC mask");
        assertEq(adapter.aTokenMask(), creditManager.getTokenMaskOrRevert(aUsdc), "Incorrect aUSDC mask");
        assertEq(adapter.tokenMask(), creditManager.getTokenMaskOrRevert(usdc), "Incorrect USDC mask");
    }

    /// @notice [AAV2W-3]: All action functions revert if called not from the multicall
    function test_AAV2W_03_action_functions_revert_if_called_not_from_multicall() public {
        _openTestCreditAccount();

        vm.startPrank(USER);
        vm.expectRevert(CallerNotCreditFacadeException.selector);
        adapter.deposit(1);

        vm.expectRevert(CallerNotCreditFacadeException.selector);
        adapter.depositAll();

        vm.expectRevert(CallerNotCreditFacadeException.selector);
        adapter.depositUnderlying(1);

        vm.expectRevert(CallerNotCreditFacadeException.selector);
        adapter.depositAllUnderlying();

        vm.expectRevert(CallerNotCreditFacadeException.selector);
        adapter.withdraw(1);

        vm.expectRevert(CallerNotCreditFacadeException.selector);
        adapter.withdrawAll();

        vm.expectRevert(CallerNotCreditFacadeException.selector);
        adapter.withdrawUnderlying(1);

        vm.expectRevert(CallerNotCreditFacadeException.selector);
        adapter.withdrawAllUnderlying();
        vm.stopPrank();
    }

    /// @notice [AAV2W-4]: `deposit` and `depositUnderlying` work correctly
    function test_AAV2W_04_deposit_works_correctly(uint256 timedelta) public {
        vm.assume(timedelta < 3 * 365 days);
        uint256 snapshot = vm.snapshot();

        for (uint256 fromUnderlying; fromUnderlying < 2; ++fromUnderlying) {
            (address creditAccount, uint256 initialBalance) =
                fromUnderlying == 1 ? _openAccountWithToken(Tokens.USDC) : _openAccountWithAToken(Tokens.USDC);
            address tokenIn = fromUnderlying == 1 ? usdc : aUsdc;

            expectAllowance(tokenIn, creditAccount, waUsdc, 0);

            vm.warp(block.timestamp + timedelta);
            if (fromUnderlying == 0) initialBalance = tokenTestSuite.balanceOf(aUsdc, creditAccount);
            uint256 depositAmount = initialBalance / 2;

            bytes memory callData = fromUnderlying == 1
                ? abi.encodeCall(WrappedAToken.depositUnderlying, (depositAmount))
                : abi.encodeCall(WrappedAToken.deposit, (depositAmount));
            expectMulticallStackCalls(address(adapter), waUsdc, USER, callData, tokenIn, waUsdc, true);
            executeOneLineMulticall(creditAccount, address(adapter), callData);

            expectBalance(tokenIn, creditAccount, initialBalance - depositAmount);
            expectBalance(waUsdc, creditAccount, depositAmount * WAD / WrappedAToken(waUsdc).exchangeRate());

            expectAllowance(tokenIn, creditAccount, waUsdc, 1);

            expectTokenIsEnabled(creditAccount, tokenIn, true);
            expectTokenIsEnabled(creditAccount, waUsdc, true);

            vm.revertTo(snapshot);
        }
    }

    /// @notice [AAV2W-5]: `depositAll` and `depositAllUnderlying` work correctly
    /// @dev Fuzzing time before deposit to see if adapter handles interest properly
    function test_AAV2W_05_depositAll_works_correctly(uint256 timedelta) public {
        vm.assume(timedelta < 3 * 365 days);
        uint256 snapshot = vm.snapshot();

        for (uint256 fromUnderlying; fromUnderlying < 2; ++fromUnderlying) {
            (address creditAccount, uint256 initialBalance) =
                fromUnderlying == 1 ? _openAccountWithToken(Tokens.USDC) : _openAccountWithAToken(Tokens.USDC);
            address tokenIn = fromUnderlying == 1 ? usdc : aUsdc;

            expectAllowance(tokenIn, creditAccount, waUsdc, 0);

            vm.warp(block.timestamp + timedelta);
            if (fromUnderlying == 0) initialBalance = tokenTestSuite.balanceOf(aUsdc, creditAccount);

            bytes memory expectedCallData = fromUnderlying == 1
                ? abi.encodeCall(WrappedAToken.depositUnderlying, (initialBalance - 1))
                : abi.encodeCall(WrappedAToken.deposit, (initialBalance - 1));
            expectMulticallStackCalls(address(adapter), waUsdc, USER, expectedCallData, tokenIn, waUsdc, true);

            bytes memory callData = fromUnderlying == 1
                ? abi.encodeCall(adapter.depositAllUnderlying, ())
                : abi.encodeCall(adapter.depositAll, ());
            executeOneLineMulticall(creditAccount, address(adapter), callData);

            expectBalance(tokenIn, creditAccount, 1);
            expectBalance(waUsdc, creditAccount, (initialBalance - 1) * WAD / WrappedAToken(waUsdc).exchangeRate());

            expectAllowance(tokenIn, creditAccount, waUsdc, 1);

            expectTokenIsEnabled(creditAccount, tokenIn, false);
            expectTokenIsEnabled(creditAccount, waUsdc, true);

            vm.revertTo(snapshot);
        }
    }

    /// @notice [AAV2W-6]: `withdraw` and `withdrawUnderlying` work correctly
    /// @dev Fuzzing time before withdrawal to see if adapter handles interest properly
    function test_AAV2W_06_withdraw_works_correctly(uint256 timedelta) public {
        vm.assume(timedelta < 3 * 365 days);
        uint256 snapshot = vm.snapshot();

        for (uint256 toUnderlying; toUnderlying < 2; ++toUnderlying) {
            (address creditAccount, uint256 initialBalance) = _openAccountWithWAToken(Tokens.USDC);
            address tokenOut = toUnderlying == 1 ? usdc : aUsdc;

            vm.warp(block.timestamp + timedelta);
            uint256 withdrawAmount = initialBalance / 2;

            bytes memory callData = toUnderlying == 1
                ? abi.encodeCall(WrappedAToken.withdrawUnderlying, (withdrawAmount))
                : abi.encodeCall(WrappedAToken.withdraw, (withdrawAmount));
            expectMulticallStackCalls(address(adapter), waUsdc, USER, callData, waUsdc, tokenOut, false);
            executeOneLineMulticall(creditAccount, address(adapter), callData);

            expectBalance(waUsdc, creditAccount, initialBalance - withdrawAmount);
            expectBalance(tokenOut, creditAccount, withdrawAmount * WrappedAToken(waUsdc).exchangeRate() / WAD);

            expectTokenIsEnabled(creditAccount, waUsdc, true);
            expectTokenIsEnabled(creditAccount, tokenOut, true);

            vm.revertTo(snapshot);
        }
    }

    /// @notice [AAV2W-7]: `withdrawAll` and `withdrawAllUnderlying` work correctly
    /// @dev Fuzzing time before withdrawal to see if adapter handles interest properly
    function test_AAV2W_07_wirhdrawAll_works_correctly(uint256 timedelta) public {
        vm.assume(timedelta < 3 * 365 days);
        uint256 snapshot = vm.snapshot();

        for (uint256 toUnderlying; toUnderlying < 2; ++toUnderlying) {
            (address creditAccount, uint256 initialBalance) = _openAccountWithWAToken(Tokens.USDC);
            address tokenOut = toUnderlying == 1 ? usdc : aUsdc;

            vm.warp(block.timestamp + timedelta);

            bytes memory expectedCallData = toUnderlying == 1
                ? abi.encodeCall(WrappedAToken.withdrawUnderlying, (initialBalance - 1))
                : abi.encodeCall(WrappedAToken.withdraw, (initialBalance - 1));
            expectMulticallStackCalls(address(adapter), waUsdc, USER, expectedCallData, waUsdc, tokenOut, false);

            bytes memory callData = toUnderlying == 1
                ? abi.encodeCall(adapter.withdrawAllUnderlying, ())
                : abi.encodeCall(adapter.withdrawAll, ());
            executeOneLineMulticall(creditAccount, address(adapter), callData);

            expectBalance(waUsdc, creditAccount, 1);
            expectBalance(tokenOut, creditAccount, (initialBalance - 1) * WrappedAToken(waUsdc).exchangeRate() / WAD);

            expectTokenIsEnabled(creditAccount, waUsdc, false);
            expectTokenIsEnabled(creditAccount, tokenOut, true);

            vm.revertTo(snapshot);
        }
    }
}
