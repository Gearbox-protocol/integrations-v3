// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { NotImplementedException } from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

import { ConvexAdapterHelper, CURVE_LP_AMOUNT, DAI_ACCOUNT_AMOUNT, REWARD_AMOUNT, REWARD_AMOUNT1, REWARD_AMOUNT2 } from "./ConvexAdapterHelper.sol";
import { ERC20Mock } from "@gearbox-protocol/core-v2/contracts/test/mocks/token/ERC20Mock.sol";

import { USER, CONFIGURATOR } from "../../lib/constants.sol";

import "@gearbox-protocol/core-v2/contracts/test/lib/test.sol";

contract ConvexV1AdapterBasePoolTest is DSTest, ConvexAdapterHelper {
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

        evm.prank(USER);
        boosterAdapter.deposit(0, CURVE_LP_AMOUNT, false);
    }

    /// @dev [ACVX1_P_01]: constructor sets correct values
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

    /// @dev [ACVX1_P_02]: constructor reverts when one of the tokens is not allowed
    function test_ACVX1_P_02_constructor_reverts_on_token_not_allowed() public {
        for (uint8 i = 0; i < 5; i++) {
            _checkPoolAdapterConstructorRevert(i);
        }
    }

    /// @dev [ACVX1_P_03]: stake works correctly and emits events
    function test_ACVX1_P_03_stake_works_correctly() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();

            address creditAccount = _openTestCreditAccountAndDeposit();

            expectAllowance(
                convexLPToken,
                creditAccount,
                address(basePoolMock),
                0
            );

            expectStakeStackCalls(USER, CURVE_LP_AMOUNT / 2, false, multicall);

            if (multicall) {
                executeOneLineMulticall(
                    address(basePoolAdapter),
                    abi.encodeWithSelector(
                        basePoolAdapter.stake.selector,
                        CURVE_LP_AMOUNT / 2
                    )
                );
            } else {
                evm.prank(USER);
                basePoolAdapter.stake(CURVE_LP_AMOUNT / 2);
            }

            expectBalance(
                convexLPToken,
                creditAccount,
                CURVE_LP_AMOUNT - CURVE_LP_AMOUNT / 2
            );

            expectBalance(phantomToken, creditAccount, CURVE_LP_AMOUNT / 2);

            expectAllowance(
                convexLPToken,
                creditAccount,
                address(basePoolMock),
                1
            );

            expectTokenIsEnabled(phantomToken, true);

            expectSafeAllowance(address(basePoolMock));
        }
    }

    /// @dev [ACVX1_P_04]: stakeAll works correctly and emits events
    function test_ACVX1_P_04_stakeAll_works_correctly() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();

            address creditAccount = _openTestCreditAccountAndDeposit();

            expectAllowance(
                convexLPToken,
                creditAccount,
                address(basePoolMock),
                0
            );

            expectStakeStackCalls(USER, CURVE_LP_AMOUNT, true, multicall);

            if (multicall) {
                executeOneLineMulticall(
                    address(basePoolAdapter),
                    abi.encodeWithSelector(basePoolAdapter.stakeAll.selector)
                );
            } else {
                evm.prank(USER);
                basePoolAdapter.stakeAll();
            }

            expectBalance(convexLPToken, creditAccount, 0);

            expectBalance(phantomToken, creditAccount, CURVE_LP_AMOUNT);

            expectAllowance(
                convexLPToken,
                creditAccount,
                address(basePoolMock),
                1
            );

            expectTokenIsEnabled(convexLPToken, false);
            expectTokenIsEnabled(phantomToken, true);

            expectSafeAllowance(address(basePoolMock));
        }
    }

    /// @dev [ACVX1_P_05]: stakeFor reverts
    function test_ACVX1_P_05_stakeFor_reverts() public {
        evm.expectRevert(NotImplementedException.selector);
        basePoolAdapter.stakeFor(USER, 0);
    }

    /// @dev [ACVX1_P_06]: getReward works correctly and emits events
    function test_ACVX1_P_06_getReward_works_correctly() public {
        for (uint256 ii = 0; ii < 2; ii++) {
            bool isInternal = ii != 0;
            for (uint256 ce = 0; ce < 2; ce++) {
                bool claimExtras = ce != 0;
                for (uint256 numExtras; numExtras <= 2; numExtras++) {
                    for (uint256 m = 0; m < 2; m++) {
                        bool multicall = m != 0;

                        _setupConvexSuite(numExtras);

                        address creditAccount = _openTestCreditAccountAndDeposit();

                        evm.prank(USER);
                        basePoolAdapter.stakeAll();

                        basePoolMock.addRewardAmount(REWARD_AMOUNT);

                        if (isInternal) {
                            claimExtras = true;
                        }

                        if (claimExtras) {
                            if (numExtras >= 1) {
                                extraPoolMock1.addRewardAmount(REWARD_AMOUNT1);
                            }
                            if (numExtras == 2) {
                                extraPoolMock2.addRewardAmount(REWARD_AMOUNT2);
                            }
                        }

                        expectTokenIsEnabled(cvx, false);
                        expectTokenIsEnabled(crv, false);
                        expectTokenIsEnabled(extraRewardToken1, false);
                        expectTokenIsEnabled(extraRewardToken2, false);

                        expectClaimStackCalls(
                            USER,
                            claimExtras,
                            isInternal,
                            multicall,
                            numExtras
                        );

                        if (multicall) {
                            executeOneLineMulticall(
                                address(basePoolAdapter),
                                isInternal
                                    ? abi.encodeWithSignature("getReward()")
                                    : abi.encodeWithSignature(
                                        "getReward(address,bool)",
                                        creditAccount,
                                        claimExtras
                                    )
                            );
                        } else {
                            if (isInternal) {
                                evm.prank(USER);
                                basePoolAdapter.getReward();
                            } else {
                                basePoolAdapter.getReward(
                                    creditAccount,
                                    claimExtras
                                );
                            }
                        }
                        expectBalance(crv, creditAccount, REWARD_AMOUNT);
                        expectBalance(cvx, creditAccount, REWARD_AMOUNT);

                        expectBalance(
                            extraRewardToken1,
                            creditAccount,
                            claimExtras && numExtras >= 1 ? REWARD_AMOUNT1 : 0
                        );
                        expectBalance(
                            extraRewardToken2,
                            creditAccount,
                            claimExtras && numExtras == 2 ? REWARD_AMOUNT2 : 0
                        );

                        expectTokenIsEnabled(cvx, true);
                        expectTokenIsEnabled(crv, true);
                        expectTokenIsEnabled(
                            extraRewardToken1,
                            claimExtras && numExtras >= 1
                        );
                        expectTokenIsEnabled(
                            extraRewardToken2,
                            claimExtras && numExtras == 2
                        );
                        expectSafeAllowance(address(basePoolMock));
                    }
                }
            }
        }
    }

    /// @dev [ACVX1_P_09]: withdraw works correctly and emits events
    function test_ACVX1_P_09_withdraw_works_correctly() public {
        for (uint256 numExtras; numExtras <= 2; numExtras++) {
            for (uint256 m = 0; m < 2; m++) {
                bool multicall = m != 0;

                _setupConvexSuite(numExtras);

                address creditAccount = _openTestCreditAccountAndDeposit();

                evm.prank(USER);
                basePoolAdapter.stakeAll();

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
                    multicall,
                    numExtras
                );

                if (multicall) {
                    executeOneLineMulticall(
                        address(basePoolAdapter),
                        abi.encodeWithSelector(
                            basePoolAdapter.withdraw.selector,
                            CURVE_LP_AMOUNT / 2,
                            true
                        )
                    );
                } else {
                    evm.prank(USER);
                    basePoolAdapter.withdraw(CURVE_LP_AMOUNT / 2, true);
                }
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
                expectBalance(
                    convexLPToken,
                    creditAccount,
                    CURVE_LP_AMOUNT / 2
                );

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
    }

    /// @dev [ACVX1_P_10]: withdrawAll works correctly and emits events
    function test_ACVX1_P_10_withdrawAll_works_correctly() public {
        for (uint256 numExtras; numExtras <= 2; numExtras++) {
            for (uint256 m = 0; m < 2; m++) {
                bool multicall = m != 0;

                _setupConvexSuite(numExtras);

                address creditAccount = _openTestCreditAccountAndDeposit();

                evm.prank(USER);
                basePoolAdapter.stakeAll();

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
                    multicall,
                    numExtras
                );

                if (multicall) {
                    executeOneLineMulticall(
                        address(basePoolAdapter),
                        abi.encodeWithSelector(
                            basePoolAdapter.withdrawAll.selector,
                            true
                        )
                    );
                } else {
                    evm.prank(USER);
                    basePoolAdapter.withdrawAll(true);
                }

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
    }

    /// @dev [ACVX1_P_11]: withdrawAndUnwrap works correctly and emits events
    function test_ACVX1_P_11_withdrawAndUnwrap_works_correctly() public {
        for (uint256 numExtras; numExtras <= 2; numExtras++) {
            for (uint256 m = 0; m < 2; m++) {
                bool multicall = m != 0;

                _setupConvexSuite(numExtras);

                address creditAccount = _openTestCreditAccountAndDeposit();

                evm.prank(USER);
                basePoolAdapter.stakeAll();

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
                    multicall,
                    numExtras
                );

                if (multicall) {
                    executeOneLineMulticall(
                        address(basePoolAdapter),
                        abi.encodeWithSelector(
                            basePoolAdapter.withdrawAndUnwrap.selector,
                            CURVE_LP_AMOUNT / 2,
                            true
                        )
                    );
                } else {
                    evm.prank(USER);
                    basePoolAdapter.withdrawAndUnwrap(
                        CURVE_LP_AMOUNT / 2,
                        true
                    );
                }
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
    }

    /// @dev [ACVX1_P_12]: withdrawAllAndUnwrap works correctly and emits events
    function test_ACVX1_P_12_withdrawAllAndUnwrap_works_correctly() public {
        for (uint256 numExtras; numExtras <= 2; numExtras++) {
            for (uint256 m = 0; m < 2; m++) {
                bool multicall = m != 0;

                _setupConvexSuite(numExtras);

                address creditAccount = _openTestCreditAccountAndDeposit();

                evm.prank(USER);
                basePoolAdapter.stakeAll();

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
                    multicall,
                    numExtras
                );

                if (multicall) {
                    executeOneLineMulticall(
                        address(basePoolAdapter),
                        abi.encodeWithSelector(
                            basePoolAdapter.withdrawAllAndUnwrap.selector,
                            true
                        )
                    );
                } else {
                    evm.prank(USER);
                    basePoolAdapter.withdrawAllAndUnwrap(true);
                }
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

    /// @dev [ACVX1_P_13]: getters are consistent with target contract
    function test_ACVX1_P_13_getters_are_consistent() public {
        address creditAccount = _openTestCreditAccountAndDeposit();

        evm.prank(USER);
        basePoolAdapter.stakeAll();

        basePoolMock.addRewardAmount(REWARD_AMOUNT);

        assertEq(
            basePoolMock.earned(creditAccount),
            basePoolAdapter.earned(creditAccount),
            "earned() is not consistent"
        );

        assertEq(
            basePoolMock.lastTimeRewardApplicable(),
            basePoolAdapter.lastTimeRewardApplicable(),
            "lastTimeRewardApplicable() is not consistent"
        );

        assertEq(
            basePoolMock.rewardPerToken(),
            basePoolAdapter.rewardPerToken(),
            "rewardPerToken() is not consistent"
        );

        assertEq(
            basePoolMock.totalSupply(),
            basePoolAdapter.totalSupply(),
            "totalSupply() is not consistent"
        );

        assertEq(
            basePoolMock.balanceOf(creditAccount),
            basePoolAdapter.balanceOf(creditAccount),
            "balanceOf() is not consistent"
        );

        assertEq(
            basePoolMock.extraRewardsLength(),
            basePoolAdapter.extraRewardsLength(),
            "extraRewardsLength() is not consistent"
        );

        assertEq(
            address(basePoolMock.rewardToken()),
            address(basePoolAdapter.rewardToken()),
            "rewardToken() is not consistent"
        );

        assertEq(
            address(basePoolMock.stakingToken()),
            address(basePoolAdapter.stakingToken()),
            "stakingToken() is not consistent"
        );

        assertEq(
            basePoolMock.duration(),
            basePoolAdapter.duration(),
            "duration() is not consistent"
        );

        assertEq(
            basePoolMock.operator(),
            basePoolAdapter.operator(),
            "operator() is not consistent"
        );

        assertEq(
            basePoolMock.rewardManager(),
            basePoolAdapter.rewardManager(),
            "rewardManager() is not consistent"
        );

        assertEq(
            basePoolMock.pid(),
            basePoolAdapter.pid(),
            "pid() is not consistent"
        );

        assertEq(
            basePoolMock.periodFinish(),
            basePoolAdapter.periodFinish(),
            "periodFinish() is not consistent"
        );

        assertEq(
            basePoolMock.rewardRate(),
            basePoolAdapter.rewardRate(),
            "rewardRate() is not consistent"
        );

        assertEq(
            basePoolMock.lastUpdateTime(),
            basePoolAdapter.lastUpdateTime(),
            "lastUpdateTime() is not consistent"
        );

        assertEq(
            basePoolMock.rewardPerTokenStored(),
            basePoolAdapter.rewardPerTokenStored(),
            "rewardPerTokenStored() is not consistent"
        );

        assertEq(
            basePoolMock.queuedRewards(),
            basePoolAdapter.queuedRewards(),
            "queuedRewards() is not consistent"
        );

        assertEq(
            basePoolMock.currentRewards(),
            basePoolAdapter.currentRewards(),
            "currentRewards() is not consistent"
        );

        assertEq(
            basePoolMock.historicalRewards(),
            basePoolAdapter.historicalRewards(),
            "historicalRewards() is not consistent"
        );

        assertEq(
            basePoolMock.newRewardRatio(),
            basePoolAdapter.newRewardRatio(),
            "newRewardRatio() is not consistent"
        );

        assertEq(
            basePoolMock.rewards(creditAccount),
            basePoolAdapter.rewards(creditAccount),
            "rewards() is not consistent"
        );

        evm.prank(USER);
        basePoolAdapter.getReward();

        assertEq(
            basePoolMock.userRewardPerTokenPaid(creditAccount),
            basePoolAdapter.userRewardPerTokenPaid(creditAccount),
            "userRewardPerTokenPaid() is not consistent"
        );

        assertEq(
            basePoolMock.extraRewards(0),
            basePoolAdapter.extraRewards(0),
            "extraRewards(0) is not consistent"
        );

        assertEq(
            basePoolMock.extraRewards(1),
            basePoolAdapter.extraRewards(1),
            "extraRewards(1) is not consistent"
        );
    }
}
