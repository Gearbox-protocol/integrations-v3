// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IBooster} from "../../../../integrations/convex/IBooster.sol";

import {ConvexAdapterHelper, CURVE_LP_AMOUNT, DAI_ACCOUNT_AMOUNT} from "./ConvexAdapterHelper.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {USER, CONFIGURATOR} from "../../../lib/constants.sol";

import {CallerNotConfiguratorException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

contract ConvexV1BoosterAdapterTest is Test, ConvexAdapterHelper {
    address creditAccount;

    function setUp() public {
        _setupConvexSuite(2);

        (creditAccount,) = _openTestCreditAccount();
    }

    ///
    /// TESTS
    ///

    /// @dev [ACVX1_B-1]: updateStakedPhantomTokensMap reverts when called not by configurtator
    function test_ACVX1_B_01_updateStakedPhantomTokensMap_access_restricted() public {
        vm.prank(CONFIGURATOR);
        boosterAdapter.updateStakedPhantomTokensMap();

        vm.expectRevert(CallerNotConfiguratorException.selector);
        vm.prank(USER);
        boosterAdapter.updateStakedPhantomTokensMap();
    }

    /// @dev [ACVX1_B-2]: deposit function works correctly and emits events
    function test_ACVX1_B_02_deposit_works_correctly() public {
        for (uint256 st = 0; st < 2; st++) {
            bool staking = st != 0;

            setUp();

            ERC20Mock(curveLPToken).mint(creditAccount, CURVE_LP_AMOUNT);

            expectAllowance(curveLPToken, creditAccount, address(boosterMock), 0);

            expectDepositStackCalls(USER, CURVE_LP_AMOUNT / 2, staking, false);

            executeOneLineMulticall(
                address(boosterAdapter), abi.encodeCall(boosterAdapter.deposit, (0, CURVE_LP_AMOUNT / 2, staking))
            );

            expectBalance(curveLPToken, creditAccount, CURVE_LP_AMOUNT - CURVE_LP_AMOUNT / 2);

            expectBalance(staking ? phantomToken : convexLPToken, creditAccount, CURVE_LP_AMOUNT / 2);
            expectAllowance(curveLPToken, creditAccount, address(boosterMock), 1);

            expectTokenIsEnabled(convexLPToken, !staking);
            expectTokenIsEnabled(phantomToken, staking);

            expectSafeAllowance(address(boosterMock));
        }
    }

    /// @dev [ACVX1_B_03]: depositAll function works correctly and emits events
    function test_ACVX1_B_03_depositAll_works_correctly() public {
        for (uint256 st = 0; st < 2; st++) {
            bool staking = st != 0;

            setUp();

            ERC20Mock(curveLPToken).mint(creditAccount, CURVE_LP_AMOUNT);

            expectAllowance(curveLPToken, creditAccount, address(boosterMock), 0);

            expectDepositStackCalls(USER, CURVE_LP_AMOUNT, staking, true);

            executeOneLineMulticall(address(boosterAdapter), abi.encodeCall(boosterAdapter.depositAll, (0, staking)));

            expectBalance(curveLPToken, creditAccount, 0);

            expectBalance(staking ? phantomToken : convexLPToken, creditAccount, CURVE_LP_AMOUNT);

            expectAllowance(curveLPToken, creditAccount, address(boosterMock), 1);

            expectTokenIsEnabled(curveLPToken, false);
            expectTokenIsEnabled(convexLPToken, !staking);
            expectTokenIsEnabled(phantomToken, staking);

            expectSafeAllowance(address(boosterMock));
        }
    }

    /// @dev [ACVX1_B-4]: withdraw function works correctly and emits events
    function test_ACVX1_B_04_withdraw_works_correctly() public {
        setUp();

        ERC20Mock(curveLPToken).mint(creditAccount, CURVE_LP_AMOUNT);

        executeOneLineMulticall(
            address(boosterAdapter), abi.encodeCall(boosterAdapter.deposit, (0, CURVE_LP_AMOUNT, false))
        );

        expectAllowance(convexLPToken, creditAccount, address(boosterMock), 0);

        expectWithdrawStackCalls(USER, CURVE_LP_AMOUNT / 2, false);

        executeOneLineMulticall(
            address(boosterAdapter), abi.encodeCall(boosterAdapter.withdraw, (0, CURVE_LP_AMOUNT / 2))
        );

        expectBalance(curveLPToken, creditAccount, CURVE_LP_AMOUNT / 2);

        expectBalance(convexLPToken, creditAccount, CURVE_LP_AMOUNT - CURVE_LP_AMOUNT / 2);

        expectAllowance(convexLPToken, creditAccount, address(boosterMock), 0);

        expectTokenIsEnabled(curveLPToken, true);

        expectSafeAllowance(address(boosterMock));
    }

    /// @dev [ACVX1_B-5]: withdrawAll function works correctly and emits events
    function test_ACVX1_B_05_withdrawAll_works_correctly() public {
        setUp();

        ERC20Mock(curveLPToken).mint(creditAccount, CURVE_LP_AMOUNT);

        executeOneLineMulticall(
            address(boosterAdapter), abi.encodeCall(boosterAdapter.deposit, (0, CURVE_LP_AMOUNT, false))
        );
        expectAllowance(convexLPToken, creditAccount, address(boosterMock), 0);

        expectWithdrawStackCalls(USER, CURVE_LP_AMOUNT, true);

        executeOneLineMulticall(address(boosterAdapter), abi.encodeCall(boosterAdapter.withdrawAll, (0)));

        expectBalance(curveLPToken, creditAccount, CURVE_LP_AMOUNT);

        expectBalance(convexLPToken, creditAccount, 0);

        expectAllowance(convexLPToken, creditAccount, address(boosterMock), 0);

        expectTokenIsEnabled(convexLPToken, false);

        expectTokenIsEnabled(curveLPToken, true);

        expectSafeAllowance(address(boosterMock));
    }
}
