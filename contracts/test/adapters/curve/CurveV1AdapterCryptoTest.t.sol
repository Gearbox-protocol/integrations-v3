// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {CurveV1AdapterBase} from "../../../adapters/curve/CurveV1_Base.sol";
import {ICurveV1Adapter} from "../../../interfaces/curve/ICurveV1Adapter.sol";
import {ICurvePool} from "../../../integrations/curve/ICurvePool.sol";

import {CurveV1Mock} from "../../mocks/integrations/CurveV1Mock.sol";

import {Tokens} from "../../suites/TokensTestSuite.sol";

import {ICurvePool2Assets} from "../../../integrations/curve/ICurvePool_2.sol";
import {ICurvePool3Assets} from "../../../integrations/curve/ICurvePool_3.sol";
import {ICurvePool4Assets} from "../../../integrations/curve/ICurvePool_4.sol";

// TEST
import "../../lib/constants.sol";

import {CurveV1AdapterHelper} from "./CurveV1AdapterHelper.sol";

// EXCEPTIONS
import {
    ZeroAddressException, NotImplementedException
} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";
import {ICreditManagerV2Exceptions} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";

/// @title CurveV1AdapterBaseTest
/// @notice Designed for unit test purposes only
contract CurveV1AdapterBaseTest is DSTest, CurveV1AdapterHelper {
    ICurveV1Adapter public adapter;
    CurveV1Mock public curveV1Mock;

    function setUp() public {
        _setUpCurveCryptoSuite();

        curveV1Mock = CurveV1Mock(_curveV1MockAddr);

        curveV1Mock.setRate(0, 1, 100 * RAY);

        curveV1Mock.setRateUnderlying(0, 1, 100 * RAY);
        curveV1Mock.setRateUnderlying(0, 2, 99 * RAY);
        curveV1Mock.setRateUnderlying(0, 3, 99 * RAY);

        adapter = CurveV1AdapterBase(_adapterAddr);
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [ACC-1]: constructor sets correct values
    function test_ACC_01_constructor_sets_correct_values() public {
        assertTrue(adapter.use256(), "Adapter incorrectly uses int128");
    }

    /// @dev [ACC-2]: exchange works for user as expected
    function test_ACC_02_exchange_works_for_user_as_expected() public {
        setUp();

        address tokenIn = tokenTestSuite.addressOf(Tokens.cLINK);
        address tokenOut = curveV1Mock.coins(uint256(1));

        (address creditAccount,) = _openTestCreditAccount();

        addCollateral(Tokens.cLINK, LINK_ACCOUNT_AMOUNT);

        expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 0);

        bytes memory callData = abi.encodeWithSignature(
            "exchange(uint256,uint256,uint256,uint256)", 0, 1, LINK_EXCHANGE_AMOUNT, LINK_EXCHANGE_AMOUNT * 100
        );

        expectMulticallStackCalls(address(adapter), address(curveV1Mock), USER, callData, tokenIn, tokenOut, false);

        executeOneLineMulticall(address(adapter), callData);

        expectBalance(Tokens.cLINK, creditAccount, LINK_ACCOUNT_AMOUNT - LINK_EXCHANGE_AMOUNT);

        expectBalance(tokenOut, creditAccount, LINK_EXCHANGE_AMOUNT * 100);

        expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 1);

        expectTokenIsEnabled(tokenOut, true);
    }

    /// @dev [ACC-3]: exchange_all works for user as expected
    function test_ACC_03_exchange_all_works_for_user_as_expected() public {
        setUp();

        address tokenIn = tokenTestSuite.addressOf(Tokens.cLINK);
        address tokenOut = curveV1Mock.coins(uint256(1));

        (address creditAccount,) = _openTestCreditAccount();

        expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 0);

        addCollateral(Tokens.cLINK, LINK_ACCOUNT_AMOUNT);

        bytes memory callData = abi.encodeWithSignature(
            "exchange(uint256,uint256,uint256,uint256)", 0, 1, LINK_ACCOUNT_AMOUNT - 1, (LINK_ACCOUNT_AMOUNT - 1) * 100
        );

        expectMulticallStackCalls(address(adapter), address(curveV1Mock), USER, callData, tokenIn, tokenOut, false);

        executeOneLineMulticall(
            address(adapter), abi.encodeWithSignature("exchange_all(uint256,uint256,uint256)", 0, 1, RAY * 100)
        );

        expectBalance(tokenIn, creditAccount, 1);

        expectBalance(tokenOut, creditAccount, (LINK_ACCOUNT_AMOUNT - 1) * 100);

        expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 1);

        expectTokenIsEnabled(tokenIn, false);
        expectTokenIsEnabled(tokenOut, true);
    }

    /// @dev [ACC-4]: exchange_underlying works for user as expected
    function test_ACC_04_exchange_underlying_works_for_user_as_expected() public {
        setUp();
        address tokenIn = tokenTestSuite.addressOf(Tokens.cLINK);
        address tokenOut = tokenTestSuite.addressOf(Tokens.cUSDT);

        (address creditAccount,) = _openTestCreditAccount();

        expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 0);

        addCollateral(Tokens.cLINK, LINK_ACCOUNT_AMOUNT);

        bytes memory callData = abi.encodeWithSignature(
            "exchange_underlying(uint256,uint256,uint256,uint256)",
            0,
            3,
            LINK_EXCHANGE_AMOUNT,
            LINK_EXCHANGE_AMOUNT * 99
        );

        expectMulticallStackCalls(address(adapter), address(curveV1Mock), USER, callData, tokenIn, tokenOut, false);

        executeOneLineMulticall(address(adapter), callData);

        expectBalance(Tokens.cLINK, creditAccount, LINK_ACCOUNT_AMOUNT - LINK_EXCHANGE_AMOUNT);

        expectBalance(Tokens.cUSDT, creditAccount, LINK_EXCHANGE_AMOUNT * 99);

        expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 1);

        expectTokenIsEnabled(tokenOut, true);
    }

    /// @dev [ACC-5]: exchange_all_underlying works for user as expected
    function test_ACC_05_exchange_all_underlying_works_for_user_as_expected() public {
        address tokenIn = tokenTestSuite.addressOf(Tokens.cLINK);
        address tokenOut = tokenTestSuite.addressOf(Tokens.cUSDT);

        (address creditAccount,) = _openTestCreditAccount();

        addCollateral(Tokens.cLINK, LINK_ACCOUNT_AMOUNT);

        bytes memory callData = abi.encodeWithSignature(
            "exchange_underlying(uint256,uint256,uint256,uint256)",
            0,
            3,
            LINK_ACCOUNT_AMOUNT - 1,
            (LINK_ACCOUNT_AMOUNT - 1) * 99
        );

        expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 0);

        expectMulticallStackCalls(address(adapter), address(curveV1Mock), USER, callData, tokenIn, tokenOut, false);

        executeOneLineMulticall(
            address(adapter),
            abi.encodeWithSignature("exchange_all_underlying(uint256,uint256,uint256)", 0, 3, RAY * 99)
        );

        expectBalance(Tokens.cLINK, creditAccount, 1);

        expectBalance(Tokens.cUSDT, creditAccount, (LINK_ACCOUNT_AMOUNT - 1) * 99);

        expectTokenIsEnabled(tokenIn, false);
        expectTokenIsEnabled(tokenOut, true);
    }

    /// @dev [ACC-6]: add_all_liquidity_one_coin works for user as expected
    function test_ACC_06_add_all_liquidity_one_coin_works_for_user_as_expected() public {
        for (uint256 i = 0; i < 2; i++) {
            setUp();

            address tokenIn = curveV1Mock.coins(i);
            address tokenOut = lpToken;

            // tokenTestSuite.mint(Tokens.DAI, USER, DAI_ACCOUNT_AMOUNT);
            (address creditAccount,) = _openTestCreditAccount();

            tokenTestSuite.mint(tokenIn, USER, LINK_ACCOUNT_AMOUNT);
            addCollateral(tokenIn, LINK_ACCOUNT_AMOUNT);

            bytes memory callData = abi.encodeWithSignature("add_all_liquidity_one_coin(uint256,uint256)", i, RAY / 2);

            bytes memory expectedCallData;

            uint256[2] memory amounts;
            amounts[i] = LINK_ACCOUNT_AMOUNT - 1;
            expectedCallData = abi.encodeCall(ICurvePool2Assets.add_liquidity, (amounts, (LINK_ACCOUNT_AMOUNT - 1) / 2));

            expectMulticallStackCalls(
                address(adapter), address(curveV1Mock), USER, expectedCallData, tokenIn, tokenOut, true
            );

            executeOneLineMulticall(address(adapter), callData);

            expectBalance(tokenIn, creditAccount, 1);

            expectBalance(curveV1Mock.token(), creditAccount, (LINK_ACCOUNT_AMOUNT - 1) / 2);

            expectTokenIsEnabled(tokenIn, false);
            expectTokenIsEnabled(curveV1Mock.token(), true);

            expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 1);

            _closeTestCreditAccount();
        }
    }

    /// @dev [ACС-7]: add_liquidity_one_coin works for user as expected
    function test_ACC_07_add_liquidity_one_coin_works_for_user_as_expected() public {
        for (uint256 i = 0; i < 2; i++) {
            setUp();

            address tokenIn = curveV1Mock.coins(i);
            address tokenOut = lpToken;

            // tokenTestSuite.mint(Tokens.DAI, USER, DAI_ACCOUNT_AMOUNT);
            (address creditAccount,) = _openTestCreditAccount();

            tokenTestSuite.mint(tokenIn, USER, LINK_ACCOUNT_AMOUNT);
            addCollateral(tokenIn, LINK_ACCOUNT_AMOUNT);

            bytes memory callData = abi.encodeWithSignature(
                "add_liquidity_one_coin(uint256,uint256,uint256)", LINK_ACCOUNT_AMOUNT / 2, i, LINK_ACCOUNT_AMOUNT / 4
            );

            bytes memory expectedCallData;

            uint256[2] memory amounts;
            amounts[i] = LINK_ACCOUNT_AMOUNT / 2;
            expectedCallData = abi.encodeCall(ICurvePool2Assets.add_liquidity, (amounts, LINK_ACCOUNT_AMOUNT / 4));

            expectMulticallStackCalls(
                address(adapter), address(curveV1Mock), USER, expectedCallData, tokenIn, tokenOut, true
            );

            executeOneLineMulticall(address(adapter), callData);

            expectBalance(tokenIn, creditAccount, LINK_ACCOUNT_AMOUNT / 2);

            expectBalance(curveV1Mock.token(), creditAccount, LINK_ACCOUNT_AMOUNT / 4);

            expectTokenIsEnabled(curveV1Mock.token(), true);

            expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 1);

            _closeTestCreditAccount();
        }
    }

    /// @dev [ACC-8]: remove_liquidity_one_coin works as expected
    function test_ACC_08_remove_liquidity_one_coin_works_correctly() public {
        for (uint256 i = 0; i < 2; i++) {
            setUp();

            address tokenIn = lpToken;
            address tokenOut = curveV1Mock.coins(i);

            (address creditAccount,) = _openTestCreditAccount();

            // provide LP token to creditAccount
            addCRVCollateral(curveV1Mock, CURVE_LP_ACCOUNT_AMOUNT);

            bytes memory expectedCallData = abi.encodeWithSignature(
                "remove_liquidity_one_coin(uint256,uint256,uint256)",
                CURVE_LP_OPERATION_AMOUNT,
                i,
                CURVE_LP_OPERATION_AMOUNT / 2
            );

            tokenTestSuite.mint(tokenOut, address(curveV1Mock), USDT_ACCOUNT_AMOUNT);

            expectMulticallStackCalls(
                address(adapter), address(curveV1Mock), USER, expectedCallData, tokenIn, tokenOut, false
            );

            executeOneLineMulticall(address(adapter), expectedCallData);

            expectBalance(tokenIn, creditAccount, CURVE_LP_ACCOUNT_AMOUNT - CURVE_LP_OPERATION_AMOUNT);
            expectBalance(tokenOut, creditAccount, CURVE_LP_OPERATION_AMOUNT / 2);

            expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 0);

            expectTokenIsEnabled(tokenOut, true);
        }
    }

    /// @dev [ACC-9]: remove_all_liquidity_one_coin works as expected
    function test_ACC_09_remove_all_liquidity_one_coin_works_correctly() public {
        for (uint256 i = 0; i < 2; i++) {
            setUp();

            address tokenIn = lpToken;
            address tokenOut = curveV1Mock.coins(i);

            uint256 rateRAY = RAY / 2;

            (address creditAccount,) = _openTestCreditAccount();

            // provide LP token to creditAccount
            addCRVCollateral(curveV1Mock, CURVE_LP_ACCOUNT_AMOUNT);

            tokenTestSuite.mint(tokenOut, address(curveV1Mock), USDT_ACCOUNT_AMOUNT);

            bytes memory expectedCallData = abi.encodeWithSignature(
                "remove_liquidity_one_coin(uint256,uint256,uint256)",
                CURVE_LP_ACCOUNT_AMOUNT - 1,
                int128(int256(i)),
                (CURVE_LP_ACCOUNT_AMOUNT - 1) / 2
            );

            expectMulticallStackCalls(
                address(adapter), address(curveV1Mock), USER, expectedCallData, tokenIn, tokenOut, false
            );

            executeOneLineMulticall(
                address(adapter), abi.encodeWithSignature("remove_all_liquidity_one_coin(uint256,uint256)", i, rateRAY)
            );

            expectBalance(tokenIn, creditAccount, 1);
            expectBalance(tokenOut, creditAccount, (CURVE_LP_ACCOUNT_AMOUNT - 1) / 2);

            expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 0);

            expectTokenIsEnabled(tokenIn, false);
            expectTokenIsEnabled(tokenOut, true);
        }
    }

    /// @dev [ACV1-15]: Adapter calc_add_one_coin works correctly
    function test_ACV1_15_calc_add_one_coin_works_correctly(uint256 amount) public {
        evm.assume(amount < 10 ** 27);
        _setUp();
        for (uint256 i = 0; i < 2; i++) {
            int128 i128 = (int128(uint128(i)));

            curveV1Mock.setDepositRate(i128, RAY * i);

            assertEq(adapter.calc_add_one_coin(amount, uint256(i)), amount * i, "Incorrect ammount");
        }
    }
}
