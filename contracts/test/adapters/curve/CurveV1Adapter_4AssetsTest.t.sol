// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { N_COINS, CurveV1Adapter4Assets } from "../../../adapters/curve/CurveV1_4.sol";
import { CurveV1AdapterBase } from "../../../adapters/curve/CurveV1_Base.sol";

import { ICurvePool4Assets } from "../../../integrations/curve/ICurvePool_4.sol";
import { CurveV1Mock_4Assets } from "../../mocks/integrations/CurveV1Mock_4Assets.sol";

import { Tokens } from "../../suites/TokensTestSuite.sol";

// TEST
import "../../lib/constants.sol";

import { CurveV1AdapterHelper, DAI_TO_LP, USDC_TO_LP, USDT_TO_LP, LINK_TO_LP } from "./CurveV1AdapterHelper.sol";

// EXCEPTIONS
import { ZeroAddressException } from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";
import { ICreditManagerV2Exceptions } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";

/// @title CurveV1Adapter4AssetsTest
/// @notice Designed for unit test purposes only
contract CurveV1Adapter4AssetsTest is DSTest, CurveV1AdapterHelper {
    CurveV1Adapter4Assets public adapter;
    CurveV1Mock_4Assets public curveV1Mock;

    function setUp() public {
        _setupCurveSuite(N_COINS);
        curveV1Mock = CurveV1Mock_4Assets(_curveV1MockAddr);
        adapter = CurveV1Adapter4Assets(_adapterAddr);
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [ACV1_4-1]: constructor sets correct values
    function test_ACV1_4_01_constructor_sets_correct_values() public {
        assertEq(
            address(adapter.token0()),
            tokenTestSuite.addressOf(Tokens.cDAI),
            "Incorrect token0"
        );
        assertEq(
            address(adapter.token1()),
            tokenTestSuite.addressOf(Tokens.cUSDC),
            "Incorrect token1"
        );
        assertEq(
            address(adapter.token2()),
            tokenTestSuite.addressOf(Tokens.cUSDT),
            "Incorrect token2"
        );
        assertEq(
            address(adapter.token3()),
            tokenTestSuite.addressOf(Tokens.cLINK),
            "Incorrect token3"
        );
    }

    /// @dev [ACV1_3-2]: constructor reverts for zero addresses
    function test_ACV1_4_02_constructor_reverts_for_zero_addresses() public {
        for (uint256 i = 0; i < N_COINS; i++) {
            address[] memory poolTokens = getPoolTokens(N_COINS);
            poolTokens[i] = address(0);

            curveV1Mock = new CurveV1Mock_4Assets(poolTokens, poolTokens);

            address lp_token = curveV1Mock.lp_token();
            addMockPriceFeed(lp_token, 1e8);

            evm.prank(CONFIGURATOR);
            creditConfigurator.addCollateralToken(lp_token, 8800);

            evm.expectRevert(
                abi.encodeWithSelector(ZeroAddressException.selector)
            );
            adapter = new CurveV1Adapter4Assets(
                address(creditManager),
                address(curveV1Mock),
                lp_token,
                address(0)
            );
        }
    }

    /// @dev [ACV1_4-2A]: constructor reverts for zero addresses
    function test_ACV1_4_02A_constructor_reverts_for_unknown_addresses()
        public
    {
        for (uint256 i = 0; i < N_COINS; i++) {
            address[] memory poolTokens = getPoolTokens(N_COINS);
            poolTokens[i] = tokenTestSuite.addressOf(Tokens.LUNA);

            curveV1Mock = new CurveV1Mock_4Assets(poolTokens, poolTokens);

            address lp_token = curveV1Mock.lp_token();
            addMockPriceFeed(lp_token, 1e8);

            evm.prank(CONFIGURATOR);
            creditConfigurator.addCollateralToken(lp_token, 8800);

            evm.expectRevert(
                abi.encodeWithSelector(
                    TokenIsNotInAllowedList.selector,
                    tokenTestSuite.addressOf(Tokens.LUNA)
                )
            );
            adapter = new CurveV1Adapter4Assets(
                address(creditManager),
                address(curveV1Mock),
                lp_token,
                address(0)
            );
        }
    }

    /// @dev [ACV1_4-3]: liquidity functions revert if user has no account
    function test_ACV1_4_03_liquidity_functions_revert_if_user_has_no_account()
        public
    {
        uint256[N_COINS] memory data = [
            uint256(1),
            uint256(2),
            uint256(3),
            uint256(4)
        ];

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.add_liquidity(data, 0);

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.remove_liquidity(0, data);

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.remove_liquidity_imbalance(data, 1);
    }

    /// @dev [ACV1_4-4]: add_liquidity works as expected(
    function test_ACV1_4_04_add_liquidity_works_as_expected() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();

            (address creditAccount, ) = _openTestCreditAccount();

            addCollateral(Tokens.cDAI, DAI_ACCOUNT_AMOUNT);
            addCollateral(Tokens.cUSDC, USDC_ACCOUNT_AMOUNT);
            addCollateral(Tokens.cUSDT, USDT_ACCOUNT_AMOUNT);
            addCollateral(Tokens.cLINK, LINK_ACCOUNT_AMOUNT);

            expectAllowance(
                Tokens.cDAI,
                creditAccount,
                address(curveV1Mock),
                0
            );

            expectAllowance(
                Tokens.cUSDC,
                creditAccount,
                address(curveV1Mock),
                0
            );

            expectAllowance(
                Tokens.cUSDT,
                creditAccount,
                address(curveV1Mock),
                0
            );

            expectAllowance(
                Tokens.cLINK,
                creditAccount,
                address(curveV1Mock),
                0
            );

            uint256[N_COINS] memory amounts = [
                DAI_TO_LP,
                USDC_TO_LP,
                USDT_TO_LP,
                LINK_TO_LP
            ];

            bytes memory callData = abi.encodeWithSelector(
                CurveV1Adapter4Assets.add_liquidity.selector,
                amounts,
                CURVE_LP_OPERATION_AMOUNT
            );

            expectAddLiquidityCalls(USER, callData, N_COINS, multicall);

            if (multicall) {
                executeOneLineMulticall(address(adapter), callData);
            } else {
                evm.prank(USER);
                adapter.add_liquidity(amounts, CURVE_LP_OPERATION_AMOUNT);
            }

            expectBalance(
                Tokens.cDAI,
                creditAccount,
                DAI_ACCOUNT_AMOUNT - DAI_TO_LP
            );

            expectBalance(
                Tokens.cUSDC,
                creditAccount,
                USDC_ACCOUNT_AMOUNT - USDC_TO_LP
            );

            expectBalance(
                Tokens.cUSDT,
                creditAccount,
                USDT_ACCOUNT_AMOUNT - USDT_TO_LP
            );

            expectBalance(
                Tokens.cLINK,
                creditAccount,
                LINK_ACCOUNT_AMOUNT - LINK_TO_LP
            );

            expectBalance(
                curveV1Mock.token(),
                creditAccount,
                CURVE_LP_OPERATION_AMOUNT
            );

            expectTokenIsEnabled(curveV1Mock.token(), true);

            expectAllowance(
                Tokens.cDAI,
                creditAccount,
                address(curveV1Mock),
                type(uint256).max
            );

            expectAllowance(
                Tokens.cUSDC,
                creditAccount,
                address(curveV1Mock),
                type(uint256).max
            );

            expectAllowance(
                Tokens.cUSDT,
                creditAccount,
                address(curveV1Mock),
                type(uint256).max
            );

            expectAllowance(
                Tokens.cLINK,
                creditAccount,
                address(curveV1Mock),
                type(uint256).max
            );
        }
    }

    /// @dev [ACV1_4-4A]: add_all_liquidity_one_coin works as expected(
    function test_ACV1_4_04A_add_all_liquidity_one_coin_works_as_expected()
        public
    {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();
            address tokenIn = tokenTestSuite.addressOf(Tokens.cUSDT);
            address tokenOut = lpToken;

            (address creditAccount, ) = _openTestCreditAccount();

            addCollateral(Tokens.cUSDT, USDT_ACCOUNT_AMOUNT);

            uint256[N_COINS] memory amounts = [
                0,
                0,
                USDT_ACCOUNT_AMOUNT - 1,
                0
            ];

            bytes memory callData = abi.encodeWithSelector(
                CurveV1AdapterBase.add_all_liquidity_one_coin.selector,
                2,
                RAY / 2
            );

            bytes memory expectedCallData = abi.encodeWithSelector(
                ICurvePool4Assets.add_liquidity.selector,
                amounts,
                (USDT_ACCOUNT_AMOUNT - 1) / 2
            );

            expectAllowance(
                Tokens.cUSDT,
                creditAccount,
                address(curveV1Mock),
                0
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(curveV1Mock),
                    USER,
                    expectedCallData,
                    tokenIn,
                    tokenOut,
                    false,
                    true
                );

                executeOneLineMulticall(address(adapter), callData);
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(curveV1Mock),
                    USER,
                    expectedCallData,
                    tokenIn,
                    tokenOut,
                    false,
                    true
                );

                evm.prank(USER);
                adapter.add_all_liquidity_one_coin(2, RAY / 2);
            }

            expectBalance(Tokens.cUSDT, creditAccount, 1);

            expectBalance(
                curveV1Mock.token(),
                creditAccount,
                (USDT_ACCOUNT_AMOUNT - 1) / 2
            );

            expectTokenIsEnabled(curveV1Mock.token(), true);

            expectAllowance(
                Tokens.cUSDT,
                creditAccount,
                address(curveV1Mock),
                type(uint256).max
            );
        }
    }

    /// @dev [ACV1_4-5]: remove_liquidity works as expected(
    function test_ACV1_4_05_remove_liquidity_works_as_expected() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();

            (address creditAccount, ) = _openTestCreditAccount();

            // provide LP token to creditAccount
            addCRVCollateral(curveV1Mock, CURVE_LP_ACCOUNT_AMOUNT);

            uint256[N_COINS] memory amounts = [
                DAI_TO_LP,
                USDC_TO_LP,
                USDT_TO_LP,
                LINK_TO_LP
            ];

            bytes memory callData = abi.encodeWithSelector(
                CurveV1Adapter4Assets.remove_liquidity.selector,
                CURVE_LP_OPERATION_AMOUNT,
                amounts
            );

            expectRemoveLiquidityCalls(USER, callData, N_COINS, multicall);

            if (multicall) {
                executeOneLineMulticall(address(adapter), callData);
            } else {
                evm.prank(USER);
                adapter.remove_liquidity(CURVE_LP_OPERATION_AMOUNT, amounts);
            }
            expectBalance(Tokens.cDAI, creditAccount, DAI_TO_LP);

            expectBalance(Tokens.cUSDC, creditAccount, USDC_TO_LP);

            expectBalance(Tokens.cUSDT, creditAccount, USDT_TO_LP);

            expectBalance(Tokens.cLINK, creditAccount, LINK_TO_LP);

            expectBalance(
                curveV1Mock.token(),
                creditAccount,
                CURVE_LP_ACCOUNT_AMOUNT - CURVE_LP_OPERATION_AMOUNT
            );

            expectAllowance(
                curveV1Mock.token(),
                creditAccount,
                address(curveV1Mock),
                0
            );

            expectTokenIsEnabled(Tokens.cDAI, true);
            expectTokenIsEnabled(Tokens.cUSDC, true);
            expectTokenIsEnabled(Tokens.cUSDT, true);
            expectTokenIsEnabled(Tokens.cLINK, true);
        }
    }

    /// @dev [ACV1_4-6]: remove_liquidity_imbalance works as expected(
    function test_ACV1_4_06_remove_liquidity_imbalance_works_as_expected()
        public
    {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();

            (address creditAccount, ) = _openTestCreditAccount();

            addCRVCollateral(curveV1Mock, CURVE_LP_ACCOUNT_AMOUNT);
            uint256[N_COINS] memory expectedAmounts = [
                0,
                0,
                USDT_TO_LP,
                LINK_TO_LP
            ];

            bytes memory callData = abi.encodeWithSelector(
                CurveV1Adapter4Assets.remove_liquidity_imbalance.selector,
                expectedAmounts,
                CURVE_LP_OPERATION_AMOUNT
            );

            expectRemoveLiquidityImbalanceCalls(
                USER,
                callData,
                N_COINS,
                expectedAmounts,
                multicall
            );

            if (multicall) {
                executeOneLineMulticall(address(adapter), callData);
            } else {
                evm.prank(USER);
                adapter.remove_liquidity_imbalance(
                    expectedAmounts,
                    CURVE_LP_OPERATION_AMOUNT
                );
            }

            expectBalance(Tokens.cDAI, creditAccount, 0);

            expectBalance(Tokens.cUSDC, creditAccount, 0);

            expectBalance(Tokens.cUSDT, creditAccount, USDT_TO_LP);

            expectBalance(Tokens.cLINK, creditAccount, LINK_TO_LP);

            expectBalance(
                curveV1Mock.token(),
                creditAccount,
                CURVE_LP_ACCOUNT_AMOUNT - CURVE_LP_OPERATION_AMOUNT
            );

            expectAllowance(
                curveV1Mock.token(),
                creditAccount,
                address(curveV1Mock),
                0
            );

            expectTokenIsEnabled(Tokens.cDAI, false);
            expectTokenIsEnabled(Tokens.cUSDC, false);
            expectTokenIsEnabled(Tokens.cUSDT, true);
            expectTokenIsEnabled(Tokens.cLINK, true);
        }
    }
}
