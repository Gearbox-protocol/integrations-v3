// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {IAdapterExceptions} from "@gearbox-protocol/core-v3/contracts/interfaces/adapters/IAdapter.sol";
import {CONFIGURATOR, USER} from "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

import {CompoundV2_CErc20Adapter} from "../../../adapters/compound/CompoundV2_CErc20Adapter.sol";
import {CompoundV2_CEtherAdapter} from "../../../adapters/compound/CompoundV2_CEtherAdapter.sol";
import {CompoundV2_CTokenAdapter} from "../../../adapters/compound/CompoundV2_CTokenAdapter.sol";
import {ICompoundV2_Exceptions} from "../../../interfaces/compound/ICompoundV2_CTokenAdapter.sol";

import {Tokens} from "../../config/Tokens.sol";
import {
    CErc20Mock,
    MINT_ERROR,
    REDEEM_ERROR,
    REDEEM_UNDERLYING_ERROR
} from "../../mocks/integrations/compound/CErc20Mock.sol";

import {CompoundTestHelper} from "./CompoundTestHelper.sol";

/// @title Compound V2 CToken adapter test
/// @notice [ACV2CT]: Unit tests for Compound V2 CToken adapter
contract CompoundV2_CTokenAdapter_Test is CompoundTestHelper {
    CompoundV2_CEtherAdapter cethAdapter;
    CompoundV2_CErc20Adapter cusdcAdapter;

    function setUp() public {
        _setupCompoundSuite();

        evm.startPrank(CONFIGURATOR);
        cethAdapter = new CompoundV2_CEtherAdapter(address(creditManager), address(gateway));
        creditConfigurator.allowContract(address(gateway), address(cethAdapter));
        evm.label(address(cethAdapter), "cETH_ADAPTER");

        cusdcAdapter = new CompoundV2_CErc20Adapter(address(creditManager), cusdc);
        creditConfigurator.allowContract(cusdc, address(cusdcAdapter));
        evm.label(address(cusdcAdapter), "cUSDC_ADAPTER");
        evm.stopPrank();
    }

    /// @notice [ACV2CT-1]: All action functions revert if called not from the multicall
    function test_ACV2CT_01_action_functions_revert_if_called_not_from_multicall() public {
        _openTestCreditAccount();

        evm.startPrank(USER);
        for (uint256 isUsdc; isUsdc < 2; ++isUsdc) {
            CompoundV2_CTokenAdapter adapter =
                isUsdc == 1 ? CompoundV2_CTokenAdapter(cusdcAdapter) : CompoundV2_CTokenAdapter(cethAdapter);

            evm.expectRevert(IAdapterExceptions.CreditFacadeOnlyException.selector);
            adapter.mint(1);

            evm.expectRevert(IAdapterExceptions.CreditFacadeOnlyException.selector);
            adapter.mintAll();

            evm.expectRevert(IAdapterExceptions.CreditFacadeOnlyException.selector);
            adapter.redeem(1);

            evm.expectRevert(IAdapterExceptions.CreditFacadeOnlyException.selector);
            adapter.redeemAll();

            evm.expectRevert(IAdapterExceptions.CreditFacadeOnlyException.selector);
            adapter.redeemUnderlying(1);
        }
        evm.stopPrank();
    }

    /// @notice [ACV2CT-2] `mint` works correctly
    /// @dev Fuzzing time before deposit to see if adapter handles interest correctly
    function test_ACV2CT_02_mint_works_correctly(uint256 timedelta) public {
        evm.assume(timedelta < 3 * 365 days);
        uint256 snapshot = evm.snapshot();

        for (uint256 isUsdc; isUsdc < 2; ++isUsdc) {
            CompoundV2_CTokenAdapter adapter =
                isUsdc == 1 ? CompoundV2_CTokenAdapter(cusdcAdapter) : CompoundV2_CTokenAdapter(cethAdapter);

            (address creditAccount, address underlying, address cToken, uint256 initialBalance) =
                _openAccountWithToken(isUsdc == 1 ? Tokens.USDC : Tokens.WETH);

            address targetContract = isUsdc == 1 ? cusdc : address(gateway);

            expectAllowance(underlying, creditAccount, targetContract, 0);

            evm.warp(block.timestamp + timedelta);
            uint256 amountIn = initialBalance / 2;
            uint256 amountOutExpected = amountIn * WAD / CErc20Mock(cToken).exchangeRateCurrent();

            bytes memory callData = abi.encodeCall(adapter.mint, (amountIn));
            expectMulticallStackCalls(address(adapter), targetContract, USER, callData, underlying, cToken, true);
            executeOneLineMulticall(address(adapter), callData);

            expectBalance(underlying, creditAccount, initialBalance - amountIn);
            expectBalance(cToken, creditAccount, amountOutExpected);

            expectAllowance(underlying, creditAccount, targetContract, 1);

            expectTokenIsEnabled(underlying, true);
            expectTokenIsEnabled(cusdc, true);

            evm.revertTo(snapshot);
        }
    }

    /// @notice [ACV2CT-3] `mint` reverts on non-zero Compound error code
    /// @dev This is only relevant for CErc20 adapter because for CEther gateway reverts even sooner
    function test_ACV2CT_03_mint_reverts_on_non_zero_compound_error_code() public {
        _openAccountWithToken(Tokens.USDC);

        CErc20Mock(cusdc).setFailing(true);

        evm.expectRevert(abi.encodeWithSelector(ICompoundV2_Exceptions.CTokenError.selector, MINT_ERROR));
        executeOneLineMulticall(address(cusdcAdapter), abi.encodeCall(cusdcAdapter.mint, (1)));
    }

    /// @notice [ACV2CT-4] `mintAll` works correctly
    /// @dev Fuzzing time before deposit to see if adapter handles interest correctly
    function test_ACV2CT_04_mintAll_works_correctly(uint256 timedelta) public {
        evm.assume(timedelta < 3 * 365 days);
        uint256 snapshot = evm.snapshot();

        for (uint256 isUsdc; isUsdc < 2; ++isUsdc) {
            CompoundV2_CTokenAdapter adapter =
                isUsdc == 1 ? CompoundV2_CTokenAdapter(cusdcAdapter) : CompoundV2_CTokenAdapter(cethAdapter);

            (address creditAccount, address underlying, address cToken, uint256 initialBalance) =
                _openAccountWithToken(isUsdc == 1 ? Tokens.USDC : Tokens.WETH);

            address targetContract = isUsdc == 1 ? cusdc : address(gateway);

            expectAllowance(underlying, creditAccount, targetContract, 0);

            evm.warp(block.timestamp + timedelta);
            uint256 amountInExpected = initialBalance - 1;
            uint256 amountOutExpected = amountInExpected * WAD / CErc20Mock(cToken).exchangeRateCurrent();

            bytes memory expectedCallData = abi.encodeCall(CErc20Mock.mint, (amountInExpected));
            expectMulticallStackCalls(
                address(adapter), targetContract, USER, expectedCallData, underlying, cToken, true
            );

            bytes memory callData = abi.encodeCall(adapter.mintAll, ());
            executeOneLineMulticall(address(adapter), callData);

            expectBalance(underlying, creditAccount, initialBalance - amountInExpected);
            expectBalance(cToken, creditAccount, amountOutExpected);

            expectAllowance(underlying, creditAccount, targetContract, 1);

            expectTokenIsEnabled(underlying, false);
            expectTokenIsEnabled(cusdc, true);

            evm.revertTo(snapshot);
        }
    }

    /// @notice [ACV2CT-5] `mintAll` reverts on non-zero Compound error code
    /// @dev This is only relevant for CErc20 adapter because for CEther gateway reverts even sooner
    function test_ACV2CT_05_mintAll_reverts_on_non_zero_compound_error_code() public {
        _openAccountWithToken(Tokens.USDC);

        CErc20Mock(cusdc).setFailing(true);

        evm.expectRevert(abi.encodeWithSelector(ICompoundV2_Exceptions.CTokenError.selector, MINT_ERROR));
        executeOneLineMulticall(address(cusdcAdapter), abi.encodeCall(cusdcAdapter.mintAll, ()));
    }

    /// @notice [ACV2CT-6] `redeem` works correctly
    /// @dev Fuzzing time before withdrawal to see if adapter handles interest correctly
    function test_ACV2CT_06_redeem_works_correctly(uint256 timedelta) public {
        evm.assume(timedelta < 3 * 365 days);
        uint256 snapshot = evm.snapshot();

        for (uint256 isUsdc; isUsdc < 2; ++isUsdc) {
            CompoundV2_CTokenAdapter adapter =
                isUsdc == 1 ? CompoundV2_CTokenAdapter(cusdcAdapter) : CompoundV2_CTokenAdapter(cethAdapter);

            (address creditAccount, address underlying, address cToken, uint256 initialBalance) =
                _openAccountWithCToken(isUsdc == 1 ? Tokens.USDC : Tokens.WETH);

            address targetContract = isUsdc == 1 ? cusdc : address(gateway);

            evm.warp(block.timestamp + timedelta);
            uint256 amountIn = initialBalance / 2;
            uint256 amountOutExpected = amountIn * CErc20Mock(cToken).exchangeRateCurrent() / WAD;

            bytes memory callData = abi.encodeCall(adapter.redeem, (amountIn));
            bool cethOnly = isUsdc == 0;
            expectMulticallStackCalls(address(adapter), targetContract, USER, callData, cToken, underlying, cethOnly);
            executeOneLineMulticall(address(adapter), callData);

            expectBalance(underlying, creditAccount, amountOutExpected);
            expectBalance(cToken, creditAccount, initialBalance - amountIn);

            expectTokenIsEnabled(underlying, true);
            expectTokenIsEnabled(cToken, true);

            evm.revertTo(snapshot);
        }
    }

    /// @notice [ACV2CT-7] `redeem` reverts on non-zero Compound error code
    /// @dev This is only relevant for CErc20 adapter because for CEther gateway reverts even sooner
    function test_ACV2CT_07_redeem_reverts_on_non_zero_compound_error_code() public {
        _openAccountWithCToken(Tokens.USDC);

        CErc20Mock(cusdc).setFailing(true);

        evm.expectRevert(abi.encodeWithSelector(ICompoundV2_Exceptions.CTokenError.selector, REDEEM_ERROR));
        executeOneLineMulticall(address(cusdcAdapter), abi.encodeCall(cusdcAdapter.redeem, (1)));
    }

    /// @notice [ACV2CT-8] `redeemAll` works correctly
    /// @dev Fuzzing time before withdrawal to see if adapter handles interest correctly
    function test_ACV2CT_08_redeemAll_works_correctly(uint256 timedelta) public {
        evm.assume(timedelta < 3 * 365 days);
        uint256 snapshot = evm.snapshot();

        for (uint256 isUsdc; isUsdc < 2; ++isUsdc) {
            CompoundV2_CTokenAdapter adapter =
                isUsdc == 1 ? CompoundV2_CTokenAdapter(cusdcAdapter) : CompoundV2_CTokenAdapter(cethAdapter);

            (address creditAccount, address underlying, address cToken, uint256 initialBalance) =
                _openAccountWithCToken(isUsdc == 1 ? Tokens.USDC : Tokens.WETH);

            address targetContract = isUsdc == 1 ? cusdc : address(gateway);

            evm.warp(block.timestamp + timedelta);
            uint256 amountInExpected = initialBalance - 1;
            uint256 amountOutExpected = amountInExpected * CErc20Mock(cToken).exchangeRateCurrent() / WAD;

            bool cethOnly = isUsdc == 0;
            bytes memory expectedCallData = abi.encodeCall(CErc20Mock.redeem, (amountInExpected));
            expectMulticallStackCalls(
                address(adapter), targetContract, USER, expectedCallData, cToken, underlying, cethOnly
            );

            bytes memory callData = abi.encodeCall(adapter.redeemAll, ());
            executeOneLineMulticall(address(adapter), callData);

            expectBalance(underlying, creditAccount, amountOutExpected);
            expectBalance(cToken, creditAccount, initialBalance - amountInExpected);

            expectTokenIsEnabled(underlying, true);
            expectTokenIsEnabled(cToken, false);

            evm.revertTo(snapshot);
        }
    }

    /// @notice [ACV2CT-9] `redeemAll` reverts on non-zero Compound error code
    /// @dev This is only relevant for CErc20 adapter because for CEther gateway reverts even sooner
    function test_ACV2CT_09_redeemAll_reverts_on_non_zero_compound_error_code() public {
        _openAccountWithCToken(Tokens.USDC);

        CErc20Mock(cusdc).setFailing(true);

        evm.expectRevert(abi.encodeWithSelector(ICompoundV2_Exceptions.CTokenError.selector, REDEEM_ERROR));
        executeOneLineMulticall(address(cusdcAdapter), abi.encodeCall(cusdcAdapter.redeemAll, ()));
    }

    /// @notice [ACV2CT-10] `redeemUnderlying` works correctly
    /// @dev Fuzzing time before withdrawal to see if adapter handles interest correctly
    function test_ACV2CT_10_redeemUnderlying_works_correctly(uint256 timedelta) public {
        evm.assume(timedelta < 3 * 365 days);
        uint256 snapshot = evm.snapshot();

        for (uint256 isUsdc; isUsdc < 2; ++isUsdc) {
            CompoundV2_CTokenAdapter adapter =
                isUsdc == 1 ? CompoundV2_CTokenAdapter(cusdcAdapter) : CompoundV2_CTokenAdapter(cethAdapter);

            (address creditAccount, address underlying, address cToken, uint256 initialBalance) =
                _openAccountWithCToken(isUsdc == 1 ? Tokens.USDC : Tokens.WETH);

            address targetContract = isUsdc == 1 ? cusdc : address(gateway);

            evm.warp(block.timestamp + timedelta);
            uint256 amountOut = (initialBalance / 2) * CErc20Mock(cToken).exchangeRateCurrent() / WAD;
            uint256 amountInExpected = amountOut * WAD / CErc20Mock(cToken).exchangeRateCurrent();

            bytes memory callData = abi.encodeCall(adapter.redeemUnderlying, (amountOut));
            bool cethOnly = isUsdc == 0;
            expectMulticallStackCalls(address(adapter), targetContract, USER, callData, cToken, underlying, cethOnly);
            executeOneLineMulticall(address(adapter), callData);

            expectBalance(underlying, creditAccount, amountOut);
            expectBalance(cToken, creditAccount, initialBalance - amountInExpected);

            expectTokenIsEnabled(underlying, true);
            expectTokenIsEnabled(cToken, true);

            evm.revertTo(snapshot);
        }
    }

    /// @notice [ACV2CT-11] `redeemUnderlying` reverts on non-zero Compound error code
    /// @dev This is only relevant for CErc20 adapter because for CEther gateway reverts even sooner
    function test_ACV2CT_11_redeemUnderlying_reverts_on_non_zero_compound_error_code() public {
        _openAccountWithCToken(Tokens.USDC);

        CErc20Mock(cusdc).setFailing(true);

        evm.expectRevert(abi.encodeWithSelector(ICompoundV2_Exceptions.CTokenError.selector, REDEEM_UNDERLYING_ERROR));
        executeOneLineMulticall(address(cusdcAdapter), abi.encodeCall(cusdcAdapter.redeemUnderlying, (1)));
    }
}
