// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {N_COINS} from "../../../integrations/curve/ICurvePoolStETH.sol";

import {CurveV1AdapterStETH} from "../../../adapters/curve/CurveV1_stETH.sol";

import {ICurvePool} from "../../../integrations/curve/ICurvePool.sol";
import {ICurvePool2Assets} from "../../../integrations/curve/ICurvePool_2.sol";
import {CurveV1Mock} from "../../mocks/integrations/CurveV1Mock.sol";

import {Tokens} from "../../suites/TokensTestSuite.sol";

// TEST
import "../../lib/constants.sol";

import {CurveV1AdapterHelper} from "./CurveV1AdapterHelper.sol";

// EXCEPTIONS
import {
    ZeroAddressException, NotImplementedException
} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

uint256 constant STETH_ADD_LIQUIDITY_AMOUNT = STETH_ACCOUNT_AMOUNT / 10;
uint256 constant WETH_ADD_LIQUIDITY_AMOUNT = WETH_ACCOUNT_AMOUNT / 5;
uint256 constant WETH_REMOVE_LIQUIDITY_AMOUNT = WETH_ACCOUNT_AMOUNT / 5;
uint256 constant RATE = 2;

/// @title CurveV1StEthAdapterTest
/// @notice Designed for unit test purposes only
contract CurveV1StEthAdapterTest is DSTest, CurveV1AdapterHelper {
    CurveV1AdapterStETH public adapter;
    CurveV1Mock public curveV1Mock;
    address public lp_token;

    function setUp() public {
        _setUpCurveStETHSuite();

        curveV1Mock = CurveV1Mock(_curveV1stETHMockAddr);
        curveV1Mock.setRate(0, 1, RATE * RAY); // WETH / STETH = 2

        adapter = CurveV1AdapterStETH(_adapterStETHAddr);

        tokenTestSuite.mint(Tokens.STETH, address(curveV1Mock), STETH_ACCOUNT_AMOUNT);

        evm.deal(address(curveV1Mock), WETH_ACCOUNT_AMOUNT);

        lp_token = curveV1Mock.lp_token();
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [ACV1S-1]: add_liquidity works correctly
    function test_ACV1S_01_add_liquidity_works_correctly() public {
        setUp();

        (address creditAccount, uint256 initialWethBalance) = _openTestCreditAccount();

        evm.prank(USER);
        addCollateral(Tokens.STETH, STETH_ACCOUNT_AMOUNT);

        expectAllowance(Tokens.WETH, creditAccount, _curveV1stETHPoolGateway, 0);

        expectAllowance(Tokens.STETH, creditAccount, _curveV1stETHPoolGateway, 0);

        uint256 ethalanceBefore = address(curveV1Mock).balance;
        uint256 stethBalanceBefore = tokenTestSuite.balanceOf(Tokens.STETH, address(curveV1Mock));

        // Initial Gateway LP balance should be equal 0
        // Gateway LP balance should be equal 1
        expectBalance(lp_token, _curveV1stETHPoolGateway, 0, "setGateway lp_token != 0");

        uint256[N_COINS] memory amounts = [WETH_ADD_LIQUIDITY_AMOUNT, STETH_ADD_LIQUIDITY_AMOUNT];

        bytes memory callData = abi.encodeCall(ICurvePool2Assets.add_liquidity, (amounts, CURVE_LP_OPERATION_AMOUNT));

        expectStETHAddLiquidityCalls(USER, callData);

        executeOneLineMulticall(address(adapter), callData);

        expectBalance(Tokens.WETH, creditAccount, initialWethBalance - WETH_ADD_LIQUIDITY_AMOUNT);

        expectBalance(Tokens.STETH, creditAccount, STETH_ACCOUNT_AMOUNT - STETH_ADD_LIQUIDITY_AMOUNT);

        expectBalance(lp_token, creditAccount, CURVE_LP_OPERATION_AMOUNT - 1);

        // Gateway LP balance should be equal 1
        expectBalance(lp_token, _curveV1stETHPoolGateway, 1, "setGateway lp_token != 1");

        expectEthBalance(address(curveV1Mock), ethalanceBefore + WETH_ADD_LIQUIDITY_AMOUNT);

        expectBalance(Tokens.STETH, address(curveV1Mock), stethBalanceBefore + STETH_ADD_LIQUIDITY_AMOUNT);

        expectTokenIsEnabled(lp_token, true);

        expectAllowance(Tokens.WETH, creditAccount, _curveV1stETHPoolGateway, 1);

        expectAllowance(Tokens.STETH, creditAccount, _curveV1stETHPoolGateway, 1);
    }

    /// @dev [ACV1S-2]: remove_liquidity works correctly
    function test_ACV1S_02_remove_liquidity_works_correctly() public {
        setUp();

        (address creditAccount, uint256 initialWethBalance) = _openTestCreditAccount();

        evm.prank(USER);
        addCollateral(Tokens.STETH, STETH_ACCOUNT_AMOUNT);

        uint256 ethalanceBefore = address(curveV1Mock).balance;

        uint256[N_COINS] memory amounts = [WETH_ADD_LIQUIDITY_AMOUNT, STETH_ADD_LIQUIDITY_AMOUNT];

        uint256 STETH_REMOVE_LIQUIDITY_AMOUNT = STETH_ADD_LIQUIDITY_AMOUNT / 2;
        // uint256 WETH_REMOVE_LIQUIDITY_AMOUNT = WETH_ADD_LIQUIDITY_AMOUNT / 4;

        // Initial Gateway LP balance should be equal 0
        expectBalance(lp_token, _curveV1stETHPoolGateway, 0, "setGateway lp_token != 0");

        executeOneLineMulticall(
            address(adapter), abi.encodeCall(adapter.add_liquidity, (amounts, CURVE_LP_OPERATION_AMOUNT))
        );

        // Initial Gateway LP balance should be equal 1
        expectBalance(lp_token, _curveV1stETHPoolGateway, 1, "setGateway lp_token != 1");

        expectAllowance(lp_token, creditAccount, _curveV1stETHPoolGateway, 0);

        bytes memory callData = abi.encodeCall(
            ICurvePool2Assets.remove_liquidity,
            (CURVE_LP_OPERATION_AMOUNT / 2, [WETH_REMOVE_LIQUIDITY_AMOUNT, STETH_REMOVE_LIQUIDITY_AMOUNT])
        );

        expectStETHRemoveLiquidityCalls(USER, callData);

        executeOneLineMulticall(address(adapter), callData);

        // balance -1 cause gateway takes it for gas efficience
        expectBalance(
            Tokens.WETH,
            creditAccount,
            initialWethBalance - WETH_ADD_LIQUIDITY_AMOUNT + WETH_REMOVE_LIQUIDITY_AMOUNT - 1
        );

        // balance -1 cause gateway takes it for gas efficience
        expectBalance(
            Tokens.STETH,
            creditAccount,
            STETH_ACCOUNT_AMOUNT - STETH_ADD_LIQUIDITY_AMOUNT + STETH_REMOVE_LIQUIDITY_AMOUNT - 1
        );

        // balance -1 cause gateway takes it for gas efficience
        expectBalance(lp_token, creditAccount, (CURVE_LP_OPERATION_AMOUNT - 1) - CURVE_LP_OPERATION_AMOUNT / 2);

        // Gateway balance check
        expectBalance(Tokens.STETH, _curveV1stETHPoolGateway, 1, "stETH != 1");
        expectBalance(Tokens.WETH, _curveV1stETHPoolGateway, 1, "WETH != 1");
        expectBalance(lp_token, _curveV1stETHPoolGateway, 1, "steCRV != 1");

        expectEthBalance(
            address(curveV1Mock), ethalanceBefore + WETH_ADD_LIQUIDITY_AMOUNT - WETH_REMOVE_LIQUIDITY_AMOUNT
        );

        expectAllowance(lp_token, creditAccount, _curveV1stETHPoolGateway, 1);

        expectTokenIsEnabled(Tokens.WETH, true);
        expectTokenIsEnabled(Tokens.STETH, true);
    }

    /// @dev [ACV1S-3]: exchange works correctly
    function test_ACV1S_03_exchange_works_correctly() public {
        setUp();

        address tokenIn = tokenTestSuite.addressOf(Tokens.WETH);
        address tokenOut = tokenTestSuite.addressOf(Tokens.STETH);

        (address creditAccount, uint256 initialWethBalance) = _openTestCreditAccount();

        uint256 ethalanceBefore = address(curveV1Mock).balance;

        // uint256 WETH_EXCHANGE_AMOUNT = WETH_ACCOUNT_AMOUNT / 5;

        expectAllowance(Tokens.WETH, creditAccount, _curveV1stETHPoolGateway, 0);

        bytes memory callData =
            abi.encodeWithSignature("exchange(int128,int128,uint256,uint256)", 0, 1, WETH_EXCHANGE_AMOUNT, 0);

        expectMulticallStackCalls(address(adapter), _curveV1stETHPoolGateway, USER, callData, tokenIn, tokenOut, true);

        executeOneLineMulticall(address(adapter), callData);

        expectBalance(Tokens.WETH, creditAccount, initialWethBalance - WETH_EXCHANGE_AMOUNT);

        // balance would be -1 because of rayMul
        expectBalance(Tokens.STETH, creditAccount, WETH_EXCHANGE_AMOUNT * RATE - 1);

        expectEthBalance(address(curveV1Mock), ethalanceBefore + WETH_EXCHANGE_AMOUNT);

        expectAllowance(Tokens.WETH, creditAccount, _curveV1stETHPoolGateway, 1);

        expectTokenIsEnabled(Tokens.STETH, true);
    }

    /// @dev [ACV1S-4]: remove_liquidity_one_coin works correctly
    function test_ACV1S_04_remove_liquidity_one_coin_works_correctly() public {
        setUp();

        address tokenIn = curveV1Mock.token();
        address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

        (address creditAccount, uint256 initialWethBalance) = _openTestCreditAccount();

        uint256 ethBalanceBefore = address(curveV1Mock).balance;

        addCRVCollateral(curveV1Mock, CURVE_LP_ACCOUNT_AMOUNT);

        expectAllowance(tokenIn, creditAccount, _curveV1stETHPoolGateway, 0);

        bytes memory callData = abi.encodeWithSignature(
            "remove_liquidity_one_coin(uint256,int128,uint256)", CURVE_LP_OPERATION_AMOUNT, 0, WETH_EXCHANGE_AMOUNT
        );

        expectMulticallStackCalls(address(adapter), _curveV1stETHPoolGateway, USER, callData, tokenIn, tokenOut, true);

        executeOneLineMulticall(address(adapter), callData);

        expectBalance(tokenIn, creditAccount, CURVE_LP_ACCOUNT_AMOUNT - CURVE_LP_OPERATION_AMOUNT);

        expectBalance(tokenOut, creditAccount, initialWethBalance + WETH_EXCHANGE_AMOUNT - 1);

        expectEthBalance(address(curveV1Mock), ethBalanceBefore - WETH_EXCHANGE_AMOUNT);

        expectAllowance(tokenIn, creditAccount, _curveV1stETHPoolGateway, 1);

        expectTokenIsEnabled(Tokens.WETH, true);
    }

    /// @dev [ACV1S-5]: remove_all_liquidity_one_coin works correctly
    function test_ACV1S_05_remove_all_liquidity_one_coin_works_correctly() public {
        setUp();

        address tokenIn = curveV1Mock.token();
        address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

        (address creditAccount, uint256 initialWethBalance) = _openTestCreditAccount();

        uint256 ethBalanceBefore = address(curveV1Mock).balance;
        uint256 rateRAY = RAY / 2;

        addCRVCollateral(curveV1Mock, CURVE_LP_ACCOUNT_AMOUNT);

        expectAllowance(tokenIn, creditAccount, _curveV1stETHPoolGateway, 0);

        bytes memory expectedCallData = abi.encodeWithSignature(
            "remove_liquidity_one_coin(uint256,int128,uint256)",
            CURVE_LP_ACCOUNT_AMOUNT - 1,
            0,
            (CURVE_LP_ACCOUNT_AMOUNT - 1) / 2
        );

        expectMulticallStackCalls(
            address(adapter), _curveV1stETHPoolGateway, USER, expectedCallData, tokenIn, tokenOut, true
        );

        executeOneLineMulticall(
            address(adapter), abi.encodeWithSignature("remove_all_liquidity_one_coin(int128,uint256)", 0, rateRAY)
        );

        expectBalance(tokenIn, creditAccount, 1);

        expectBalance(tokenOut, creditAccount, initialWethBalance + ((CURVE_LP_ACCOUNT_AMOUNT - 1) / 2) - 1);

        expectEthBalance(address(curveV1Mock), ethBalanceBefore - ((CURVE_LP_ACCOUNT_AMOUNT - 1) / 2));

        expectAllowance(tokenIn, creditAccount, _curveV1stETHPoolGateway, 1);

        expectTokenIsEnabled(Tokens.WETH, true);
    }

    /// @dev [ACV1S-6]: remove_liquidity_imbalance works correctly
    function test_ACV1S_06_remove_liquidity_imbalance_works_correctly() public {
        setUp();

        address tokenIn = curveV1Mock.token();

        (address creditAccount, uint256 initialWethBalance) = _openTestCreditAccount();

        uint256 ethBalanceBefore = address(curveV1Mock).balance;

        uint256[N_COINS] memory expectedAmounts = [WETH_REMOVE_LIQUIDITY_AMOUNT, 0];

        addCRVCollateral(curveV1Mock, CURVE_LP_ACCOUNT_AMOUNT);

        expectAllowance(tokenIn, creditAccount, _curveV1stETHPoolGateway, 0);

        bytes memory callData =
            abi.encodeCall(ICurvePool2Assets.remove_liquidity_imbalance, (expectedAmounts, CURVE_LP_OPERATION_AMOUNT));

        expectStETHRemoveLiquidityImbalanceCalls(USER, callData, expectedAmounts);

        executeOneLineMulticall(address(adapter), callData);

        expectBalance(curveV1Mock.token(), creditAccount, CURVE_LP_ACCOUNT_AMOUNT - CURVE_LP_OPERATION_AMOUNT);

        expectBalance(Tokens.WETH, creditAccount, initialWethBalance + WETH_REMOVE_LIQUIDITY_AMOUNT - 1);

        expectEthBalance(address(curveV1Mock), ethBalanceBefore - WETH_REMOVE_LIQUIDITY_AMOUNT);

        expectAllowance(tokenIn, creditAccount, _curveV1stETHPoolGateway, 1);

        expectTokenIsEnabled(Tokens.WETH, true);
        expectTokenIsEnabled(Tokens.STETH, false);
    }
}
