// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {N_COINS, CurveV1Adapter3Assets} from "../../../adapters/curve/CurveV1_3.sol";
import {CurveV1Mock_3Assets} from "../../mocks/integrations/CurveV1Mock_3Assets.sol";
import {Tokens} from "../../suites/TokensTestSuite.sol";

// TEST
import "../../lib/constants.sol";
import {CurveV1AdapterHelper, DAI_TO_LP, USDC_TO_LP, USDT_TO_LP} from "./CurveV1AdapterHelper.sol";

// EXCEPTIONS
import {ZeroAddressException} from "@gearbox-protocol/core-v3/contracts/interfaces/IErrors.sol";
import {IAdapterExceptions} from "@gearbox-protocol/core-v3/contracts/interfaces/adapters/IAdapter.sol";
import {ICreditManagerV2Exceptions} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV2.sol";

/// @title CurveV1Adapter3AssetsTest
/// @notice Designed for unit test purposes only
contract CurveV1Adapter3AssetsTest is DSTest, CurveV1AdapterHelper {
    CurveV1Adapter3Assets public adapter;
    CurveV1Mock_3Assets public curveV1Mock;

    function setUp() public {
        _setupCurveSuite(N_COINS);
        curveV1Mock = CurveV1Mock_3Assets(_curveV1MockAddr);
        adapter = CurveV1Adapter3Assets(_adapterAddr);
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [ACV1_3-1]: constructor sets correct values
    function test_ACV1_3_01_constructor_sets_correct_values() public {
        assertEq(address(adapter.token0()), tokenTestSuite.addressOf(Tokens.cDAI), "Incorrect token0");
        assertEq(address(adapter.token1()), tokenTestSuite.addressOf(Tokens.cUSDC), "Incorrect token1");
        assertEq(address(adapter.token2()), tokenTestSuite.addressOf(Tokens.cUSDT), "Incorrect token2");
    }

    /// @dev [ACV1_3-2]: constructor reverts for zero addresses
    function test_ACV1_3_02_constructor_reverts_for_zero_addresses() public {
        for (uint256 i = 0; i < N_COINS; i++) {
            address[] memory poolTokens = getPoolTokens(N_COINS);
            poolTokens[i] = address(0);

            curveV1Mock = new CurveV1Mock_3Assets(poolTokens, poolTokens);

            address lp_token = curveV1Mock.lp_token();
            addMockPriceFeed(lp_token, 1e8);

            evm.prank(CONFIGURATOR);
            creditConfigurator.addCollateralToken(lp_token, 8800);

            evm.expectRevert(abi.encodeWithSelector(ZeroAddressException.selector));
            adapter = new CurveV1Adapter3Assets(
                address(creditManager),
                address(curveV1Mock),
                lp_token,
                address(0)
            );
        }
    }

    /// @dev [ACV1_3-2A]: constructor reverts for zero addresses
    function test_ACV1_3_02A_constructor_reverts_for_unknown_addresses() public {
        for (uint256 i = 0; i < N_COINS; i++) {
            address[] memory poolTokens = getPoolTokens(N_COINS);
            poolTokens[i] = tokenTestSuite.addressOf(Tokens.LUNA);

            curveV1Mock = new CurveV1Mock_3Assets(poolTokens, poolTokens);

            address lp_token = curveV1Mock.lp_token();
            addMockPriceFeed(lp_token, 1e8);

            evm.prank(CONFIGURATOR);
            creditConfigurator.addCollateralToken(lp_token, 8800);

            evm.expectRevert(IAdapterExceptions.TokenNotAllowedException.selector);
            adapter = new CurveV1Adapter3Assets(
                address(creditManager),
                address(curveV1Mock),
                lp_token,
                address(0)
            );
        }
    }

    /// @dev [ACV1_3-3]: liquidity functions revert if user has no account
    function test_ACV1_3_03_liquidity_functions_revert_if_user_has_no_account() public {
        uint256[N_COINS] memory data = [uint256(1), uint256(2), uint256(3)];

        evm.expectRevert(ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(address(adapter), abi.encodeCall(adapter.add_liquidity, (data, 0)));

        evm.expectRevert(ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(address(adapter), abi.encodeCall(adapter.remove_liquidity, (0, data)));

        evm.expectRevert(ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(address(adapter), abi.encodeCall(adapter.remove_liquidity_imbalance, (data, 1)));
    }

    /// @dev [ACV1_3-4]: add_liquidity works as expected
    function test_ACV1_3_04_add_liquidity_works_as_expected() public {
        setUp();

        (address creditAccount,) = _openTestCreditAccount();

        addCollateral(Tokens.cDAI, DAI_ACCOUNT_AMOUNT);
        addCollateral(Tokens.cUSDC, USDC_ACCOUNT_AMOUNT);
        addCollateral(Tokens.cUSDT, USDT_ACCOUNT_AMOUNT);

        expectAllowance(Tokens.cDAI, creditAccount, address(curveV1Mock), 0);

        expectAllowance(Tokens.cUSDC, creditAccount, address(curveV1Mock), 0);

        expectAllowance(Tokens.cUSDT, creditAccount, address(curveV1Mock), 0);

        uint256[N_COINS] memory amounts = [DAI_TO_LP, USDC_TO_LP, USDT_TO_LP];

        bytes memory callData =
            abi.encodeCall(CurveV1Adapter3Assets.add_liquidity, (amounts, CURVE_LP_OPERATION_AMOUNT));

        expectAddLiquidityCalls(USER, callData, N_COINS);

        executeOneLineMulticall(address(adapter), callData);

        expectBalance(Tokens.cDAI, creditAccount, DAI_ACCOUNT_AMOUNT - DAI_TO_LP);

        expectBalance(Tokens.cUSDC, creditAccount, USDC_ACCOUNT_AMOUNT - USDC_TO_LP);

        expectBalance(Tokens.cUSDT, creditAccount, USDT_ACCOUNT_AMOUNT - USDT_TO_LP);

        expectBalance(curveV1Mock.token(), creditAccount, CURVE_LP_OPERATION_AMOUNT);

        expectTokenIsEnabled(curveV1Mock.token(), true);

        expectAllowance(Tokens.cDAI, creditAccount, address(curveV1Mock), 1);

        expectAllowance(Tokens.cUSDC, creditAccount, address(curveV1Mock), 1);

        expectAllowance(Tokens.cUSDT, creditAccount, address(curveV1Mock), 1);
    }

    /// @dev [ACV1_3-5]: remove_liquidity works as expected(
    function test_ACV1_3_05_remove_liquidity_works_as_expected() public {
        setUp();
        (address creditAccount,) = _openTestCreditAccount();

        // provide LP token to creditAccount
        addCRVCollateral(curveV1Mock, CURVE_LP_ACCOUNT_AMOUNT);

        uint256[N_COINS] memory amounts = [DAI_TO_LP, USDC_TO_LP, USDT_TO_LP];

        bytes memory callData =
            abi.encodeCall(CurveV1Adapter3Assets.remove_liquidity, (CURVE_LP_OPERATION_AMOUNT, amounts));

        expectRemoveLiquidityCalls(USER, callData, N_COINS);

        executeOneLineMulticall(address(adapter), callData);

        expectBalance(Tokens.cDAI, creditAccount, DAI_TO_LP);
        expectBalance(Tokens.cUSDC, creditAccount, USDC_TO_LP);
        expectBalance(Tokens.cUSDT, creditAccount, USDT_TO_LP);

        expectBalance(curveV1Mock.token(), creditAccount, CURVE_LP_ACCOUNT_AMOUNT - CURVE_LP_OPERATION_AMOUNT);

        expectAllowance(curveV1Mock.token(), creditAccount, address(curveV1Mock), 0);

        expectTokenIsEnabled(Tokens.cDAI, true);
        expectTokenIsEnabled(Tokens.cUSDC, true);
        expectTokenIsEnabled(Tokens.cUSDT, true);
    }

    /// @dev [ACV1_3-6]: remove_liquidity_imbalance works as expected(
    function test_ACV1_3_06_remove_liquidity_imbalance_works_as_expected() public {
        setUp();
        (address creditAccount,) = _openTestCreditAccount();

        addCRVCollateral(curveV1Mock, CURVE_LP_ACCOUNT_AMOUNT);

        uint256[N_COINS] memory expectedAmounts = [0, 0, USDT_TO_LP];

        bytes memory callData = abi.encodeCall(
            CurveV1Adapter3Assets.remove_liquidity_imbalance, (expectedAmounts, CURVE_LP_OPERATION_AMOUNT)
        );

        expectRemoveLiquidityImbalanceCalls(USER, callData, N_COINS, expectedAmounts);

        executeOneLineMulticall(address(adapter), callData);

        expectBalance(Tokens.cDAI, creditAccount, 0);

        expectBalance(Tokens.cUSDC, creditAccount, 0);

        expectBalance(Tokens.cUSDT, creditAccount, USDT_TO_LP);

        expectBalance(curveV1Mock.token(), creditAccount, CURVE_LP_ACCOUNT_AMOUNT - CURVE_LP_OPERATION_AMOUNT);

        expectAllowance(curveV1Mock.token(), creditAccount, address(curveV1Mock), 0);

        expectTokenIsEnabled(Tokens.cUSDC, false);
        expectTokenIsEnabled(Tokens.cUSDT, true);
    }
}
