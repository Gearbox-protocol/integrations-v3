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
        _setUp(4);
    }

    function _setUp(uint256 nCoins) public {
        _setupCurveSuite(nCoins);

        curveV1Mock = CurveV1Mock(_curveV1MockAddr);

        curveV1Mock.setRate(0, 1, RAY); // USDC / DAI = 1 USD
        curveV1Mock.setRate(0, 2, (99 * RAY) / 100); // USDT / DAI = .99
        curveV1Mock.setRate(1, 2, (99 * RAY) / 100); // USDT / USDC = .99

        curveV1Mock.setRateUnderlying(0, 1, RAY); // USDC / DAI = 1 USD
        curveV1Mock.setRateUnderlying(0, 2, (99 * RAY) / 100); // USDT / DAI = .99
        curveV1Mock.setRateUnderlying(1, 2, (99 * RAY) / 100); // USDT / USDC = .99

        adapter = CurveV1AdapterBase(_adapterAddr);

        tokenTestSuite.mint(Tokens.USDT, address(curveV1Mock), 2 * DAI_ACCOUNT_AMOUNT);

        tokenTestSuite.mint(Tokens.USDC, address(curveV1Mock), 2 * DAI_ACCOUNT_AMOUNT);
    }

    ///
    ///
    ///  TESTS
    ///
    ///
    /// @dev [ACV1-1]: constructor reverts for zero addresses and non allowed tokens
    function test_ACV1_01_constructor_reverts_for_zero_addresses_and_non_allowed_tokens() public {
        evm.expectRevert(abi.encodeWithSelector(ZeroAddressException.selector));
        new CurveV1AdapterBase(
            address(creditManager),
            address(0),
            address(0),
            address(0),
            2
        );

        evm.expectRevert(abi.encodeWithSelector(ZeroAddressException.selector));
        new CurveV1AdapterBase(
            address(creditManager),
            address(curveV1Mock),
            address(0),
            address(0),
            2
        );

        evm.expectRevert(abi.encodeWithSelector(TokenIsNotInAllowedList.selector, DUMB_ADDRESS));

        new CurveV1AdapterBase(
            address(creditManager),
            address(curveV1Mock),
            DUMB_ADDRESS,
            address(0),
            2
        );

        address mock;

        for (uint256 i = 0; i < 4; i++) {
            uint256 nCoins = i <= 1 ? 2 : i + 1;

            address[] memory coins = new address[](nCoins);
            address[] memory underlying_coins = new address[](nCoins);

            for (uint256 j = 0; j < nCoins; j++) {
                coins[j] = tokenTestSuite.addressOf(Tokens.DAI);
                underlying_coins[j] = tokenTestSuite.addressOf(Tokens.DAI);
            }

            coins[i] = address(0);

            mock = address(new CurveV1Mock(coins, underlying_coins));
            evm.expectRevert(ZeroAddressException.selector);
            new CurveV1AdapterBase(
                address(creditManager),
                address(mock),
                lpToken,
                address(0),
                nCoins
            );
        }

        for (uint256 i = 0; i < 4; i++) {
            uint256 nCoins = i <= 1 ? 2 : i + 1;

            address[] memory coins = new address[](nCoins);
            address[] memory underlying_coins = new address[](nCoins);

            for (uint256 j = 0; j < nCoins; j++) {
                coins[j] = tokenTestSuite.addressOf(Tokens.DAI);
                underlying_coins[j] = tokenTestSuite.addressOf(Tokens.DAI);
            }

            coins[i] = DUMB_ADDRESS;

            mock = address(new CurveV1Mock(coins, underlying_coins));
            evm.expectRevert(abi.encodeWithSelector(TokenIsNotInAllowedList.selector, DUMB_ADDRESS));
            new CurveV1AdapterBase(
                address(creditManager),
                address(mock),
                lpToken,
                address(0),
                nCoins
            );

            coins[i] = tokenTestSuite.addressOf(Tokens.DAI);
            underlying_coins[i] = DUMB_ADDRESS;

            mock = address(new CurveV1Mock(coins, underlying_coins));
            evm.expectRevert(abi.encodeWithSelector(TokenIsNotInAllowedList.selector, DUMB_ADDRESS));
            new CurveV1AdapterBase(
                address(creditManager),
                address(mock),
                lpToken,
                address(0),
                nCoins
            );
        }
    }

    /// @dev [ACV1-2]: constructor sets correct values
    function test_ACV1_02_constructor_sets_correct_values() public {
        assertEq(address(adapter.creditManager()), address(creditManager), "Incorrect creditManager");
        assertEq(address(adapter.targetContract()), address(curveV1Mock), "Incorrect router");
        assertEq(address(adapter.token()), address(curveV1Mock.token()), "Incorrect LP token");

        assertEq(address(adapter.lp_token()), address(curveV1Mock.token()), "Incorrect LP token");

        assertEq(adapter.nCoins(), 4, "Incorrect nCoins");

        assertEq(address(adapter.token0()), tokenTestSuite.addressOf(poolTkns[0]), "Incorrect token 0");

        assertEq(address(adapter.token1()), tokenTestSuite.addressOf(poolTkns[1]), "Incorrect token 1");

        assertEq(address(adapter.token2()), tokenTestSuite.addressOf(poolTkns[2]), "Incorrect token 2");

        assertEq(address(adapter.token3()), tokenTestSuite.addressOf(poolTkns[3]), "Incorrect token 3");

        assertEq(
            address(adapter.underlying0()),
            tokenTestSuite.addressOf(underlyingPoolTkns[0]),
            "Incorrect underlying token 0"
        );

        assertEq(
            address(adapter.underlying1()),
            tokenTestSuite.addressOf(underlyingPoolTkns[1]),
            "Incorrect underlying token 1"
        );

        assertEq(
            address(adapter.underlying2()),
            tokenTestSuite.addressOf(underlyingPoolTkns[2]),
            "Incorrect underlying token 2"
        );

        assertEq(
            address(adapter.underlying3()),
            tokenTestSuite.addressOf(underlyingPoolTkns[3]),
            "Incorrect underlying token 3"
        );

        assertTrue(!adapter.use256(), "Adapter incorrectly uses uint256");
    }

    /// @dev [ACV1-3]: exchange reverts if user has no account
    function test_ACV1_03_swap_reverts_if_user_has_no_account() public {
        evm.expectRevert(ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(
            address(adapter), abi.encodeWithSignature("exchange(int128,int128,uint256,uint256)", 0, 1, 1, 1)
        );

        evm.expectRevert(ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(
            address(adapter), abi.encodeWithSignature("exchange_all(int128,int128,uint256)", 0, 0, 1)
        );
    }

    /// @dev [ACV1-4]: exchange works for user as expected
    function test_ACV1_04_exchange_works_for_user_as_expected() public {
        setUp();

        address tokenIn = tokenTestSuite.addressOf(Tokens.cDAI);
        address tokenOut = tokenTestSuite.addressOf(Tokens.cUSDT);

        (address creditAccount,) = _openTestCreditAccount();

        expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 0);

        addCollateral(Tokens.cDAI, DAI_ACCOUNT_AMOUNT);

        bytes memory callData = abi.encodeWithSignature(
            "exchange(int128,int128,uint256,uint256)", 0, 2, DAI_EXCHANGE_AMOUNT, (DAI_EXCHANGE_AMOUNT * 99) / 100
        );

        expectMulticallStackCalls(address(adapter), address(curveV1Mock), USER, callData, tokenIn, tokenOut, false);

        executeOneLineMulticall(address(adapter), callData);

        expectBalance(Tokens.cDAI, creditAccount, DAI_ACCOUNT_AMOUNT - DAI_EXCHANGE_AMOUNT);

        expectBalance(Tokens.cUSDT, creditAccount, (DAI_EXCHANGE_AMOUNT * 99) / 100);

        expectAllowance(tokenIn, creditAccount, address(curveV1Mock), type(uint256).max);

        expectTokenIsEnabled(tokenOut, true);
    }

    /// @dev [ACV1-5]: exchnage_all works for user as expected
    function test_ACV1_05_exchnage_all_works_for_user_as_expected() public {
        setUp();

        address tokenIn = tokenTestSuite.addressOf(Tokens.cDAI);
        address tokenOut = tokenTestSuite.addressOf(Tokens.cUSDT);

        (address creditAccount,) = _openTestCreditAccount();

        expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 0);

        addCollateral(Tokens.cDAI, DAI_ACCOUNT_AMOUNT);

        bytes memory callData = abi.encodeWithSignature(
            "exchange(int128,int128,uint256,uint256)",
            0,
            2,
            DAI_ACCOUNT_AMOUNT - 1,
            ((DAI_ACCOUNT_AMOUNT - 1) * 99) / 100
        );

        expectMulticallStackCalls(address(adapter), address(curveV1Mock), USER, callData, tokenIn, tokenOut, false);

        executeOneLineMulticall(
            address(adapter), abi.encodeWithSignature("exchange_all(int128,int128,uint256)", 0, 2, (99 * RAY) / 100)
        );

        expectBalance(Tokens.cDAI, creditAccount, 1);

        expectBalance(Tokens.cUSDT, creditAccount, ((DAI_ACCOUNT_AMOUNT - 1) * 99) / 100);

        expectAllowance(tokenIn, creditAccount, address(curveV1Mock), type(uint256).max);

        expectTokenIsEnabled(tokenIn, false);
        expectTokenIsEnabled(tokenOut, true);
    }

    /// @dev [ACV1-6]: exchange_underlying works for user as expected
    function test_ACV1_06_exchange_underlying_works_for_user_as_expected() public {
        setUp();
        address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
        address tokenOut = tokenTestSuite.addressOf(Tokens.USDT);

        (address creditAccount, uint256 initialDAIbalance) = _openTestCreditAccount();

        expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 0);

        bytes memory callData = abi.encodeWithSignature(
            "exchange_underlying(int128,int128,uint256,uint256)",
            0,
            2,
            DAI_EXCHANGE_AMOUNT,
            (DAI_EXCHANGE_AMOUNT * 99) / 100
        );

        expectMulticallStackCalls(address(adapter), address(curveV1Mock), USER, callData, tokenIn, tokenOut, false);

        executeOneLineMulticall(address(adapter), callData);

        expectBalance(Tokens.DAI, creditAccount, initialDAIbalance - DAI_EXCHANGE_AMOUNT);

        expectBalance(Tokens.USDT, creditAccount, (DAI_EXCHANGE_AMOUNT * 99) / 100);

        expectAllowance(tokenIn, creditAccount, address(curveV1Mock), type(uint256).max);

        expectTokenIsEnabled(tokenOut, true);
    }

    /// @dev [ACV1-7]: exchange_all_underlying works for user as expected
    function test_ACV1_07_exchange_all_underlying_works_for_user_as_expected() public {
        setUp();

        address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
        address tokenOut = tokenTestSuite.addressOf(Tokens.USDT);

        (address creditAccount, uint256 initialDAIbalance) = _openTestCreditAccount();

        bytes memory callData = abi.encodeWithSignature(
            "exchange_underlying(int128,int128,uint256,uint256)",
            0,
            2,
            initialDAIbalance - 1,
            ((initialDAIbalance - 1) * 99) / 100
        );

        expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 0);

        expectMulticallStackCalls(address(adapter), address(curveV1Mock), USER, callData, tokenIn, tokenOut, false);

        executeOneLineMulticall(
            address(adapter),
            abi.encodeWithSignature("exchange_all_underlying(int128,int128,uint256)", 0, 2, (99 * RAY) / 100)
        );

        expectBalance(Tokens.DAI, creditAccount, 1);

        expectBalance(Tokens.USDT, creditAccount, ((initialDAIbalance - 1) * 99) / 100);

        expectTokenIsEnabled(tokenIn, false);
        expectTokenIsEnabled(tokenOut, true);
    }

    /// @dev [ACV1-8]: add_all_liquidity_one_coin works for user as expected
    function test_ACV1_08_add_all_liquidity_one_coin_works_for_user_as_expected() public {
        for (uint256 nCoins = 2; nCoins <= 4; nCoins++) {
            for (uint256 i = 0; i < nCoins; i++) {
                _setUp(nCoins);

                address tokenIn = curveV1Mock.coins(i);
                address tokenOut = lpToken;

                // tokenTestSuite.mint(Tokens.DAI, USER, DAI_ACCOUNT_AMOUNT);
                (address creditAccount,) = _openTestCreditAccount();

                tokenTestSuite.mint(tokenIn, USER, DAI_ACCOUNT_AMOUNT);
                addCollateral(tokenIn, DAI_ACCOUNT_AMOUNT);

                bytes memory callData =
                    abi.encodeWithSignature("add_all_liquidity_one_coin(int128,uint256)", int128(int256(i)), RAY / 2);

                bytes memory expectedCallData;

                if (nCoins == 2) {
                    uint256[2] memory amounts;
                    amounts[i] = DAI_ACCOUNT_AMOUNT - 1;
                    expectedCallData =
                        abi.encodeCall(ICurvePool2Assets.add_liquidity, (amounts, (DAI_ACCOUNT_AMOUNT - 1) / 2));
                } else if (nCoins == 3) {
                    uint256[3] memory amounts;
                    amounts[i] = DAI_ACCOUNT_AMOUNT - 1;
                    expectedCallData =
                        abi.encodeCall(ICurvePool3Assets.add_liquidity, (amounts, (DAI_ACCOUNT_AMOUNT - 1) / 2));
                } else if (nCoins == 4) {
                    uint256[4] memory amounts;
                    amounts[i] = DAI_ACCOUNT_AMOUNT - 1;
                    expectedCallData =
                        abi.encodeCall(ICurvePool4Assets.add_liquidity, (amounts, (DAI_ACCOUNT_AMOUNT - 1) / 2));
                }

                expectMulticallStackCalls(
                    address(adapter), address(curveV1Mock), USER, expectedCallData, tokenIn, tokenOut, false, true
                );

                executeOneLineMulticall(address(adapter), callData);

                expectBalance(tokenIn, creditAccount, 1);

                expectBalance(curveV1Mock.token(), creditAccount, (DAI_ACCOUNT_AMOUNT - 1) / 2);

                expectTokenIsEnabled(tokenIn, false);
                expectTokenIsEnabled(curveV1Mock.token(), true);

                expectAllowance(tokenIn, creditAccount, address(curveV1Mock), type(uint256).max);

                _closeTestCreditAccount();
            }
        }
    }

    /// @dev [ACV1-8A]: add_liquidity_one_coin works for user as expected
    function test_ACV1_08A_add_liquidity_one_coin_works_for_user_as_expected() public {
        for (uint256 nCoins = 2; nCoins <= 4; nCoins++) {
            for (uint256 i = 0; i < nCoins; i++) {
                _setUp(nCoins);

                address tokenIn = curveV1Mock.coins(i);
                address tokenOut = lpToken;

                // tokenTestSuite.mint(Tokens.DAI, USER, DAI_ACCOUNT_AMOUNT);
                (address creditAccount,) = _openTestCreditAccount();

                tokenTestSuite.mint(tokenIn, USER, DAI_ACCOUNT_AMOUNT);
                addCollateral(tokenIn, DAI_ACCOUNT_AMOUNT);

                bytes memory callData = abi.encodeWithSignature(
                    "add_liquidity_one_coin(uint256,int128,uint256)",
                    DAI_ACCOUNT_AMOUNT / 2,
                    int128(int256(i)),
                    DAI_ACCOUNT_AMOUNT / 4
                );

                bytes memory expectedCallData;

                if (nCoins == 2) {
                    uint256[2] memory amounts;
                    amounts[i] = DAI_ACCOUNT_AMOUNT / 2;
                    expectedCallData =
                        abi.encodeCall(ICurvePool2Assets.add_liquidity, (amounts, DAI_ACCOUNT_AMOUNT / 4));
                } else if (nCoins == 3) {
                    uint256[3] memory amounts;
                    amounts[i] = DAI_ACCOUNT_AMOUNT / 2;
                    expectedCallData =
                        abi.encodeCall(ICurvePool3Assets.add_liquidity, (amounts, DAI_ACCOUNT_AMOUNT / 4));
                } else if (nCoins == 4) {
                    uint256[4] memory amounts;
                    amounts[i] = DAI_ACCOUNT_AMOUNT / 2;
                    expectedCallData =
                        abi.encodeCall(ICurvePool4Assets.add_liquidity, (amounts, DAI_ACCOUNT_AMOUNT / 4));
                }

                expectMulticallStackCalls(
                    address(adapter), address(curveV1Mock), USER, expectedCallData, tokenIn, tokenOut, false, true
                );

                executeOneLineMulticall(address(adapter), callData);

                expectBalance(tokenIn, creditAccount, DAI_ACCOUNT_AMOUNT / 2);

                expectBalance(curveV1Mock.token(), creditAccount, DAI_ACCOUNT_AMOUNT / 4);

                expectTokenIsEnabled(curveV1Mock.token(), true);

                expectAllowance(tokenIn, creditAccount, address(curveV1Mock), type(uint256).max);

                _closeTestCreditAccount();
            }
        }
    }

    /// @dev [ACV1-9]: remove_liquidity_one_coin works as expected
    function test_ACV1_09_remove_liquidity_one_coin_works_correctly() public {
        for (uint256 nCoins = 2; nCoins <= 4; nCoins++) {
            for (uint256 i = 0; i < nCoins; i++) {
                _setUp(nCoins);

                address tokenIn = lpToken;
                address tokenOut = curveV1Mock.coins(i);

                (address creditAccount,) = _openTestCreditAccount();

                // provide LP token to creditAccount
                addCRVCollateral(curveV1Mock, CURVE_LP_ACCOUNT_AMOUNT);

                bytes memory expectedCallData = abi.encodeWithSignature(
                    "remove_liquidity_one_coin(uint256,int128,uint256)",
                    CURVE_LP_OPERATION_AMOUNT,
                    int128(int256(i)),
                    USDT_ACCOUNT_AMOUNT / 2
                );

                tokenTestSuite.mint(tokenOut, address(curveV1Mock), USDT_ACCOUNT_AMOUNT);

                expectMulticallStackCalls(
                    address(adapter), address(curveV1Mock), USER, expectedCallData, tokenIn, tokenOut, false, false
                );

                executeOneLineMulticall(address(adapter), expectedCallData);

                expectBalance(tokenIn, creditAccount, CURVE_LP_ACCOUNT_AMOUNT - CURVE_LP_OPERATION_AMOUNT);
                expectBalance(tokenOut, creditAccount, USDT_ACCOUNT_AMOUNT / 2);

                expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 0);

                expectTokenIsEnabled(tokenOut, true);
            }
        }
    }

    /// @dev [ACV1-10]: remove_all_liquidity_one_coin works as expected
    function test_ACV1_10_remove_all_liquidity_one_coin_works_correctly() public {
        for (uint256 nCoins = 2; nCoins <= 4; nCoins++) {
            for (uint256 i = 0; i < nCoins; i++) {
                _setUp(nCoins);

                address tokenIn = lpToken;
                address tokenOut = curveV1Mock.coins(i);

                uint256 rateRAY = RAY / 2;

                (address creditAccount,) = _openTestCreditAccount();

                // provide LP token to creditAccount
                addCRVCollateral(curveV1Mock, CURVE_LP_ACCOUNT_AMOUNT);

                tokenTestSuite.mint(tokenOut, address(curveV1Mock), USDT_ACCOUNT_AMOUNT);

                bytes memory expectedCallData = abi.encodeWithSignature(
                    "remove_liquidity_one_coin(uint256,int128,uint256)",
                    CURVE_LP_ACCOUNT_AMOUNT - 1,
                    int128(int256(i)),
                    (CURVE_LP_ACCOUNT_AMOUNT - 1) / 2
                );

                expectMulticallStackCalls(
                    address(adapter), address(curveV1Mock), USER, expectedCallData, tokenIn, tokenOut, false, false
                );

                executeOneLineMulticall(
                    address(adapter),
                    abi.encodeWithSignature("remove_all_liquidity_one_coin(int128,uint256)", int128(int256(i)), rateRAY)
                );

                expectBalance(tokenIn, creditAccount, 1);
                expectBalance(tokenOut, creditAccount, (CURVE_LP_ACCOUNT_AMOUNT - 1) / 2);

                expectAllowance(tokenIn, creditAccount, address(curveV1Mock), 0);

                expectTokenIsEnabled(tokenIn, false);
                expectTokenIsEnabled(tokenOut, true);
            }
        }
    }

    /// @dev [ACV1-15]: Adapter calc_add_one_coin works correctly
    function test_ACV1_15_calc_add_one_coin_works_correctly(uint256 amount) public {
        evm.assume(amount < 10 ** 27);
        for (uint256 nCoins = 2; nCoins <= 4; nCoins++) {
            _setUp(nCoins);
            for (uint256 i = 0; i < nCoins; i++) {
                int128 i128 = (int128(uint128(i)));

                curveV1Mock.setDepositRate(i128, RAY * i);

                assertEq(adapter.calc_add_one_coin(amount, i128), amount * i, "Incorrect ammount");
            }
        }
    }
}
