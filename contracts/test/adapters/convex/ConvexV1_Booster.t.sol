// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IBooster } from "../../../integrations/convex/IBooster.sol";

import { ConvexAdapterHelper, CURVE_LP_AMOUNT, DAI_ACCOUNT_AMOUNT } from "./ConvexAdapterHelper.sol";
import { ERC20Mock } from "@gearbox-protocol/core-v2/contracts/test/mocks/token/ERC20Mock.sol";

import { USER, CONFIGURATOR } from "../../lib/constants.sol";

import "@gearbox-protocol/core-v2/contracts/test/lib/test.sol";

import { CallerNotConfiguratorException } from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

contract ConvexV1AdapterBoosterTest is DSTest, ConvexAdapterHelper {
    address creditAccount;

    function setUp() public {
        _setupConvexSuite(2);

        (creditAccount, ) = _openTestCreditAccount();
    }

    ///
    /// TESTS
    ///

    /// @dev [ACVX1_B_01]: constructor sets correct values
    function test_ACVX1_B_01_constructor_sets_correct_values() public {
        assertEq(boosterAdapter.crv(), crv, "Incorrect CRV token");
        assertEq(boosterAdapter.minter(), cvx, "Incorrect minter (CVX)");
    }

    /// @dev [ACVX1_B_02]: deposit function with stake == false works correctly and emits events
    function test_ACVX1_B_02_deposit_without_staking_works_correctly() public {
        for (uint256 st = 0; st < 2; st++) {
            bool staking = st != 0;

            for (uint256 m = 0; m < 2; m++) {
                bool multicall = m != 0;
                setUp();

                ERC20Mock(curveLPToken).mint(creditAccount, CURVE_LP_AMOUNT);

                expectAllowance(
                    curveLPToken,
                    creditAccount,
                    address(boosterMock),
                    0
                );

                expectDepositStackCalls(
                    USER,
                    CURVE_LP_AMOUNT / 2,
                    staking,
                    false,
                    multicall
                );

                if (multicall) {
                    executeOneLineMulticall(
                        address(boosterAdapter),
                        abi.encodeWithSelector(
                            boosterAdapter.deposit.selector,
                            0,
                            CURVE_LP_AMOUNT / 2,
                            staking
                        )
                    );
                } else {
                    evm.prank(USER);
                    boosterAdapter.deposit(0, CURVE_LP_AMOUNT / 2, staking);
                }
                expectBalance(
                    curveLPToken,
                    creditAccount,
                    CURVE_LP_AMOUNT - CURVE_LP_AMOUNT / 2
                );

                expectBalance(
                    staking ? phantomToken : convexLPToken,
                    creditAccount,
                    CURVE_LP_AMOUNT / 2
                );
                expectAllowance(
                    curveLPToken,
                    creditAccount,
                    address(boosterMock),
                    1
                );

                expectTokenIsEnabled(convexLPToken, !staking);
                expectTokenIsEnabled(phantomToken, staking);

                expectSafeAllowance(address(boosterMock));
            }
        }
    }

    /// @dev [ACVX1_B_03]: depositAll function with stake == false works correctly and emits events
    function test_ACVX1_B_03_depositAll_without_staking_works_correctly()
        public
    {
        for (uint256 st = 0; st < 2; st++) {
            bool staking = st != 0;

            for (uint256 m = 0; m < 2; m++) {
                bool multicall = m != 0;
                setUp();

                ERC20Mock(curveLPToken).mint(creditAccount, CURVE_LP_AMOUNT);

                expectAllowance(
                    curveLPToken,
                    creditAccount,
                    address(boosterMock),
                    0
                );

                expectDepositStackCalls(
                    USER,
                    CURVE_LP_AMOUNT,
                    staking,
                    true,
                    multicall
                );

                if (multicall) {
                    executeOneLineMulticall(
                        address(boosterAdapter),
                        abi.encodeWithSelector(
                            boosterAdapter.depositAll.selector,
                            0,
                            staking
                        )
                    );
                } else {
                    evm.prank(USER);
                    boosterAdapter.depositAll(0, staking);
                }

                expectBalance(curveLPToken, creditAccount, 0);

                expectBalance(
                    staking ? phantomToken : convexLPToken,
                    creditAccount,
                    CURVE_LP_AMOUNT
                );

                expectAllowance(
                    curveLPToken,
                    creditAccount,
                    address(boosterMock),
                    1
                );

                expectTokenIsEnabled(curveLPToken, false);
                expectTokenIsEnabled(convexLPToken, !staking);
                expectTokenIsEnabled(phantomToken, staking);

                expectSafeAllowance(address(boosterMock));
            }
        }
    }

    /// @dev [ACVX1_B_06]: withdraw function works correctly and emits events
    function test_ACVX1_B_06_withdraw_works_correctly() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();

            ERC20Mock(curveLPToken).mint(creditAccount, CURVE_LP_AMOUNT);

            evm.prank(USER);
            boosterAdapter.deposit(0, CURVE_LP_AMOUNT, false);
            expectAllowance(
                convexLPToken,
                creditAccount,
                address(boosterMock),
                0
            );

            expectWithdrawStackCalls(
                USER,
                CURVE_LP_AMOUNT / 2,
                false,
                multicall
            );

            if (multicall) {
                executeOneLineMulticall(
                    address(boosterAdapter),
                    abi.encodeWithSelector(
                        boosterAdapter.withdraw.selector,
                        0,
                        CURVE_LP_AMOUNT / 2
                    )
                );
            } else {
                evm.prank(USER);
                boosterAdapter.withdraw(0, CURVE_LP_AMOUNT / 2);
            }

            expectBalance(curveLPToken, creditAccount, CURVE_LP_AMOUNT / 2);

            expectBalance(
                convexLPToken,
                creditAccount,
                CURVE_LP_AMOUNT - CURVE_LP_AMOUNT / 2
            );

            expectAllowance(
                convexLPToken,
                creditAccount,
                address(boosterMock),
                0
            );

            expectTokenIsEnabled(curveLPToken, true);

            expectSafeAllowance(address(boosterMock));
        }
    }

    /// @dev [ACVX1_B_07]: withdrawAll function works correctly and emits events
    function test_ACVX1_B_07_withdrawAll_works_correctly() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();

            ERC20Mock(curveLPToken).mint(creditAccount, CURVE_LP_AMOUNT);

            evm.prank(USER);
            boosterAdapter.deposit(0, CURVE_LP_AMOUNT, false);

            expectAllowance(
                convexLPToken,
                creditAccount,
                address(boosterMock),
                0
            );

            expectWithdrawStackCalls(USER, CURVE_LP_AMOUNT, true, multicall);

            if (multicall) {
                executeOneLineMulticall(
                    address(boosterAdapter),
                    abi.encodeWithSelector(
                        boosterAdapter.withdrawAll.selector,
                        0
                    )
                );
            } else {
                evm.prank(USER);
                boosterAdapter.withdrawAll(0);
            }

            expectBalance(curveLPToken, creditAccount, CURVE_LP_AMOUNT);

            expectBalance(convexLPToken, creditAccount, 0);

            expectAllowance(
                convexLPToken,
                creditAccount,
                address(boosterMock),
                0
            );

            expectTokenIsEnabled(convexLPToken, false);

            expectTokenIsEnabled(curveLPToken, true);

            expectSafeAllowance(address(boosterMock));
        }
    }

    /// @dev [ACVX1_B_08]: getters are consistent with target
    function test_ACVX1_B_08_getters_are_consistent() public {
        IBooster castBoosterMock = IBooster(address(boosterMock));

        assertEq(
            boosterAdapter.poolInfo(0).lptoken,
            castBoosterMock.poolInfo(0).lptoken,
            "poolInfo.lptoken is not consistent"
        );

        assertEq(
            boosterAdapter.poolInfo(0).token,
            castBoosterMock.poolInfo(0).token,
            "poolInfo.token is not consistent"
        );

        assertEq(
            boosterAdapter.poolInfo(0).gauge,
            castBoosterMock.poolInfo(0).gauge,
            "poolInfo.gauge is not consistent"
        );

        assertEq(
            boosterAdapter.poolInfo(0).crvRewards,
            castBoosterMock.poolInfo(0).crvRewards,
            "poolInfo.crvRewards is not consistent"
        );

        assertEq(
            boosterAdapter.poolInfo(0).stash,
            castBoosterMock.poolInfo(0).stash,
            "poolInfo.stash is not consistent"
        );

        assertTrue(
            boosterAdapter.poolInfo(0).shutdown ==
                castBoosterMock.poolInfo(0).shutdown,
            "poolInfo.shutdown is not consistent"
        );

        assertEq(
            boosterAdapter.poolLength(),
            boosterMock.poolLength(),
            "poolLength is not consistent"
        );

        assertEq(
            boosterAdapter.staker(),
            boosterMock.staker(),
            "staker is not consistent"
        );
    }

    /// @dev [ACVX1_B_09]: updateStakedPhantomTokensMap reverts when called not by configurtator
    function test_ACVX1_B_09_updateStakedPhantomTokensMap_access_restricted()
        public
    {
        evm.prank(CONFIGURATOR);
        boosterAdapter.updateStakedPhantomTokensMap();

        evm.expectRevert(CallerNotConfiguratorException.selector);
        evm.prank(USER);
        boosterAdapter.updateStakedPhantomTokensMap();
    }
}
