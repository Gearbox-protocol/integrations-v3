// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { MultiCall } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacade.sol";
import { ICreditManagerV2Exceptions } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";
import { NotImplementedException } from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

import { ConvexAdapterHelper, CURVE_LP_AMOUNT, DAI_ACCOUNT_AMOUNT, REWARD_AMOUNT, REWARD_AMOUNT1, REWARD_AMOUNT2 } from "./ConvexAdapterHelper.sol";
import { ERC20Mock } from "@gearbox-protocol/core-v2/contracts/test/mocks/token/ERC20Mock.sol";

import { USER, CONFIGURATOR, FRIEND } from "../../lib/constants.sol";

import "@gearbox-protocol/core-v2/contracts/test/lib/test.sol";

contract ConvexV1AdapterBasePoolTest is
    DSTest,
    ConvexAdapterHelper,
    ICreditManagerV2Exceptions
{
    function setUp() public {
        _setupConvexSuite(2);
    }

    ///
    /// TESTS
    ///

    function _openTestCreditAccountAndDeposit()
        internal
        returns (address creditAccount)
    {
        (creditAccount, ) = _openTestCreditAccount();
        ERC20Mock(curveLPToken).mint(creditAccount, CURVE_LP_AMOUNT);

        executeOneLineMulticall(
            address(boosterAdapter),
            abi.encodeCall(boosterAdapter.deposit, (0, CURVE_LP_AMOUNT, false))
        );
    }

    /// @dev [ACVX1_P-1]: constructor sets correct values
    function test_ACVX1_P_01_constructor_sets_correct_values() public {
        for (uint256 numExtras; numExtras <= 2; numExtras++) {
            _setupConvexSuite(numExtras);

            assertEq(
                address(basePoolAdapter.rewardToken()),
                crv,
                "Incorrect CRV token"
            );

            assertEq(basePoolAdapter.cvx(), cvx, "Incorrect minter (CVX)");

            assertEq(
                basePoolMock.pid(),
                basePoolAdapter.pid(),
                "Incorrect pid"
            );

            assertEq(
                address(basePoolAdapter.stakingToken()),
                convexLPToken,
                "Incorrect Convex LP"
            );

            assertEq(
                basePoolAdapter.curveLPtoken(),
                curveLPToken,
                "Incorrect Curve LP"
            );

            if (numExtras >= 1) {
                assertEq(
                    basePoolAdapter.extraReward1(),
                    extraRewardToken1,
                    "Incorrect reward token 1"
                );
            } else {
                assertEq(
                    basePoolAdapter.extraReward1(),
                    address(0),
                    "Reward token 1 was incorrectly set to non-zero"
                );
            }

            if (numExtras == 2) {
                assertEq(
                    basePoolAdapter.extraReward2(),
                    extraRewardToken2,
                    "Incorrect reward token 2"
                );
            } else {
                assertEq(
                    basePoolAdapter.extraReward2(),
                    address(0),
                    "Reward token 2 was incorrectly set to non-zero"
                );
            }
        }
    }

    /// @dev [ACVX1_P-2]: constructor reverts when one of the tokens is not allowed
    function test_ACVX1_P_02_constructor_reverts_on_token_not_allowed() public {
        for (uint8 i = 0; i < 5; i++) {
            _checkPoolAdapterConstructorRevert(i);
        }
    }

    /// @dev [ACVX1_P-3]: stake works correctly and emits events
    function test_ACVX1_P_03_stake_works_correctly() public {
        setUp();

        address creditAccount = _openTestCreditAccountAndDeposit();

        expectAllowance(convexLPToken, creditAccount, address(basePoolMock), 0);

        expectStakeStackCalls(USER, CURVE_LP_AMOUNT / 2, false);

        executeOneLineMulticall(
            address(basePoolAdapter),
            abi.encodeCall(basePoolAdapter.stake, (CURVE_LP_AMOUNT / 2))
        );

        expectBalance(
            convexLPToken,
            creditAccount,
            CURVE_LP_AMOUNT - CURVE_LP_AMOUNT / 2
        );

        expectBalance(phantomToken, creditAccount, CURVE_LP_AMOUNT / 2);

        expectAllowance(convexLPToken, creditAccount, address(basePoolMock), 1);

        expectTokenIsEnabled(phantomToken, true);

        expectSafeAllowance(address(basePoolMock));
    }

    /// @dev [ACVX1_P-4]: stakeAll works correctly and emits events
    function test_ACVX1_P_04_stakeAll_works_correctly() public {
        setUp();

        address creditAccount = _openTestCreditAccountAndDeposit();

        expectAllowance(convexLPToken, creditAccount, address(basePoolMock), 0);

        expectStakeStackCalls(USER, CURVE_LP_AMOUNT, true);

        executeOneLineMulticall(
            address(basePoolAdapter),
            abi.encodeCall(basePoolAdapter.stakeAll, ())
        );

        expectBalance(convexLPToken, creditAccount, 0);

        expectBalance(phantomToken, creditAccount, CURVE_LP_AMOUNT);

        expectAllowance(convexLPToken, creditAccount, address(basePoolMock), 1);

        expectTokenIsEnabled(convexLPToken, false);
        expectTokenIsEnabled(phantomToken, true);

        expectSafeAllowance(address(basePoolMock));
    }

    /// @dev [ACVX1_P-5]: getReward works correctly and emits events
    function test_ACVX1_P_05_getReward_works_correctly() public {
        for (uint256 numExtras; numExtras <= 2; numExtras++) {
            _setupConvexSuite(numExtras);

            address creditAccount = _openTestCreditAccountAndDeposit();

            executeOneLineMulticall(
                address(basePoolAdapter),
                abi.encodeCall(basePoolAdapter.stakeAll, ())
            );

            basePoolMock.addRewardAmount(REWARD_AMOUNT);

            if (numExtras >= 1) {
                extraPoolMock1.addRewardAmount(REWARD_AMOUNT1);
            }
            if (numExtras == 2) {
                extraPoolMock2.addRewardAmount(REWARD_AMOUNT2);
            }

            expectTokenIsEnabled(cvx, false);
            expectTokenIsEnabled(crv, false);
            expectTokenIsEnabled(extraRewardToken1, false);
            expectTokenIsEnabled(extraRewardToken2, false);

            expectClaimStackCalls(USER, numExtras);

            executeOneLineMulticall(
                address(basePoolAdapter),
                abi.encodeCall(basePoolAdapter.getReward, ())
            );

            expectBalance(crv, creditAccount, REWARD_AMOUNT);
            expectBalance(cvx, creditAccount, REWARD_AMOUNT);

            expectBalance(
                extraRewardToken1,
                creditAccount,
                numExtras >= 1 ? REWARD_AMOUNT1 : 0
            );
            expectBalance(
                extraRewardToken2,
                creditAccount,
                numExtras == 2 ? REWARD_AMOUNT2 : 0
            );

            expectTokenIsEnabled(cvx, true);
            expectTokenIsEnabled(crv, true);
            expectTokenIsEnabled(extraRewardToken1, numExtras >= 1);
            expectTokenIsEnabled(extraRewardToken2, numExtras == 2);
            expectSafeAllowance(address(basePoolMock));
        }
    }

    /// @dev [ACVX1_P-6]: withdraw works correctly and emits events
    function test_ACVX1_P_06_withdraw_works_correctly() public {
        for (uint256 numExtras; numExtras <= 2; numExtras++) {
            _setupConvexSuite(numExtras);

            address creditAccount = _openTestCreditAccountAndDeposit();

            executeOneLineMulticall(
                address(basePoolAdapter),
                abi.encodeCall(basePoolAdapter.stakeAll, ())
            );

            basePoolMock.addRewardAmount(REWARD_AMOUNT);

            if (numExtras >= 1) {
                extraPoolMock1.addRewardAmount(REWARD_AMOUNT1);
            }
            if (numExtras == 2) {
                extraPoolMock2.addRewardAmount(REWARD_AMOUNT2);
            }

            expectTokenIsEnabled(convexLPToken, false);
            expectTokenIsEnabled(cvx, false);
            expectTokenIsEnabled(crv, false);
            expectTokenIsEnabled(extraRewardToken1, false);
            expectTokenIsEnabled(extraRewardToken2, false);

            expectPoolWithdrawStackCalls(
                USER,
                CURVE_LP_AMOUNT / 2,
                false,
                false,
                numExtras
            );

            executeOneLineMulticall(
                address(basePoolAdapter),
                abi.encodeCall(
                    basePoolAdapter.withdraw,
                    (CURVE_LP_AMOUNT / 2, true)
                )
            );

            expectBalance(crv, creditAccount, REWARD_AMOUNT);
            expectBalance(cvx, creditAccount, REWARD_AMOUNT);
            expectBalance(
                extraRewardToken1,
                creditAccount,
                numExtras >= 1 ? REWARD_AMOUNT1 : 0
            );
            expectBalance(
                extraRewardToken2,
                creditAccount,
                numExtras == 2 ? REWARD_AMOUNT2 : 0
            );
            expectBalance(convexLPToken, creditAccount, CURVE_LP_AMOUNT / 2);

            expectBalance(
                phantomToken,
                creditAccount,
                CURVE_LP_AMOUNT - CURVE_LP_AMOUNT / 2
            );

            expectTokenIsEnabled(convexLPToken, true);
            expectTokenIsEnabled(cvx, true);
            expectTokenIsEnabled(crv, true);
            expectTokenIsEnabled(extraRewardToken1, numExtras >= 1);
            expectTokenIsEnabled(extraRewardToken2, numExtras == 2);

            expectSafeAllowance(address(basePoolMock));
        }
    }

    /// @dev [ACVX1_P-7]: withdrawAll works correctly and emits events
    function test_ACVX1_P_07_withdrawAll_works_correctly() public {
        for (uint256 numExtras; numExtras <= 2; numExtras++) {
            _setupConvexSuite(numExtras);

            address creditAccount = _openTestCreditAccountAndDeposit();

            executeOneLineMulticall(
                address(basePoolAdapter),
                abi.encodeCall(basePoolAdapter.stakeAll, ())
            );

            basePoolMock.addRewardAmount(REWARD_AMOUNT);
            if (numExtras >= 1) {
                extraPoolMock1.addRewardAmount(REWARD_AMOUNT1);
            }
            if (numExtras == 2) {
                extraPoolMock2.addRewardAmount(REWARD_AMOUNT2);
            }

            expectTokenIsEnabled(phantomToken, true);
            expectTokenIsEnabled(convexLPToken, false);
            expectTokenIsEnabled(cvx, false);
            expectTokenIsEnabled(crv, false);
            expectTokenIsEnabled(extraRewardToken1, false);
            expectTokenIsEnabled(extraRewardToken2, false);

            expectPoolWithdrawStackCalls(
                USER,
                CURVE_LP_AMOUNT,
                true,
                false,
                numExtras
            );

            executeOneLineMulticall(
                address(basePoolAdapter),
                abi.encodeCall(basePoolAdapter.withdrawAll, (true))
            );

            expectBalance(crv, creditAccount, REWARD_AMOUNT);
            expectBalance(cvx, creditAccount, REWARD_AMOUNT);
            expectBalance(
                extraRewardToken1,
                creditAccount,
                numExtras >= 1 ? REWARD_AMOUNT1 : 0
            );
            expectBalance(
                extraRewardToken2,
                creditAccount,
                numExtras == 2 ? REWARD_AMOUNT2 : 0
            );
            expectBalance(convexLPToken, creditAccount, CURVE_LP_AMOUNT);
            expectBalance(phantomToken, creditAccount, 0);

            expectTokenIsEnabled(phantomToken, false);

            expectTokenIsEnabled(convexLPToken, true);
            expectTokenIsEnabled(cvx, true);
            expectTokenIsEnabled(crv, true);
            expectTokenIsEnabled(extraRewardToken1, numExtras >= 1);
            expectTokenIsEnabled(extraRewardToken2, numExtras == 2);

            expectSafeAllowance(address(basePoolMock));
        }
    }

    /// @dev [ACVX1_P-8]: withdrawAndUnwrap works correctly and emits events
    function test_ACVX1_P_08_withdrawAndUnwrap_works_correctly() public {
        for (uint256 numExtras; numExtras <= 2; numExtras++) {
            _setupConvexSuite(numExtras);

            address creditAccount = _openTestCreditAccountAndDeposit();

            executeOneLineMulticall(
                address(basePoolAdapter),
                abi.encodeCall(basePoolAdapter.stakeAll, ())
            );

            basePoolMock.addRewardAmount(REWARD_AMOUNT);
            if (numExtras >= 1) {
                extraPoolMock1.addRewardAmount(REWARD_AMOUNT1);
            }
            if (numExtras == 2) {
                extraPoolMock2.addRewardAmount(REWARD_AMOUNT2);
            }

            expectTokenIsEnabled(curveLPToken, false, "initial setup");
            expectTokenIsEnabled(cvx, false, "initial setup");
            expectTokenIsEnabled(crv, false, "initial setup");
            expectTokenIsEnabled(extraRewardToken1, false, "initial setup");
            expectTokenIsEnabled(extraRewardToken2, false, "initial setup");

            expectPoolWithdrawStackCalls(
                USER,
                CURVE_LP_AMOUNT / 2,
                false,
                true,
                numExtras
            );

            executeOneLineMulticall(
                address(basePoolAdapter),
                abi.encodeCall(
                    basePoolAdapter.withdrawAndUnwrap,
                    (CURVE_LP_AMOUNT / 2, true)
                )
            );

            expectBalance(crv, creditAccount, REWARD_AMOUNT);
            expectBalance(cvx, creditAccount, REWARD_AMOUNT);
            expectBalance(
                extraRewardToken1,
                creditAccount,
                numExtras >= 1 ? REWARD_AMOUNT1 : 0
            );
            expectBalance(
                extraRewardToken2,
                creditAccount,
                numExtras == 2 ? REWARD_AMOUNT2 : 0
            );

            expectBalance(curveLPToken, creditAccount, CURVE_LP_AMOUNT / 2);

            expectBalance(
                phantomToken,
                creditAccount,
                CURVE_LP_AMOUNT - CURVE_LP_AMOUNT / 2
            );

            expectTokenIsEnabled(curveLPToken, true);
            expectTokenIsEnabled(cvx, true);
            expectTokenIsEnabled(crv, true);
            expectTokenIsEnabled(extraRewardToken1, numExtras >= 1);
            expectTokenIsEnabled(extraRewardToken2, numExtras == 2);

            expectSafeAllowance(address(basePoolMock));
        }
    }

    /// @dev [ACVX1_P-9]: withdrawAllAndUnwrap works correctly and emits events
    function test_ACVX1_P_09_withdrawAllAndUnwrap_works_correctly() public {
        for (uint256 numExtras; numExtras <= 2; numExtras++) {
            _setupConvexSuite(numExtras);

            address creditAccount = _openTestCreditAccountAndDeposit();

            executeOneLineMulticall(
                address(basePoolAdapter),
                abi.encodeCall(basePoolAdapter.stakeAll, ())
            );

            basePoolMock.addRewardAmount(REWARD_AMOUNT);
            if (numExtras >= 1) {
                extraPoolMock1.addRewardAmount(REWARD_AMOUNT1);
            }
            if (numExtras == 2) {
                extraPoolMock2.addRewardAmount(REWARD_AMOUNT2);
            }

            expectTokenIsEnabled(phantomToken, true);
            expectTokenIsEnabled(curveLPToken, false);
            expectTokenIsEnabled(cvx, false);
            expectTokenIsEnabled(crv, false);
            expectTokenIsEnabled(extraRewardToken1, false);
            expectTokenIsEnabled(extraRewardToken2, false);

            expectPoolWithdrawStackCalls(
                USER,
                CURVE_LP_AMOUNT,
                true,
                true,
                numExtras
            );

            executeOneLineMulticall(
                address(basePoolAdapter),
                abi.encodeCall(basePoolAdapter.withdrawAllAndUnwrap, (true))
            );

            expectBalance(crv, creditAccount, REWARD_AMOUNT);
            expectBalance(cvx, creditAccount, REWARD_AMOUNT);

            expectBalance(
                extraRewardToken1,
                creditAccount,
                numExtras >= 1 ? REWARD_AMOUNT1 : 0
            );
            expectBalance(
                extraRewardToken2,
                creditAccount,
                numExtras == 2 ? REWARD_AMOUNT2 : 0
            );

            expectBalance(curveLPToken, creditAccount, CURVE_LP_AMOUNT);

            expectBalance(phantomToken, creditAccount, 0);

            expectTokenIsEnabled(phantomToken, false);

            expectTokenIsEnabled(curveLPToken, true);
            expectTokenIsEnabled(cvx, true);
            expectTokenIsEnabled(crv, true);
            expectTokenIsEnabled(extraRewardToken1, numExtras >= 1);
            expectTokenIsEnabled(extraRewardToken2, numExtras == 2);

            expectSafeAllowance(address(basePoolMock));
        }
    }
}
