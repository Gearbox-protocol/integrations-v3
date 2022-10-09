// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { ConvexAdapterHelper, CURVE_LP_AMOUNT, DAI_ACCOUNT_AMOUNT, REWARD_AMOUNT, REWARD_AMOUNT1, REWARD_AMOUNT2 } from "./ConvexAdapterHelper.sol";
import { ERC20Mock } from "@gearbox-protocol/core-v2/contracts/test/mocks/token/ERC20Mock.sol";
import { TokenRewardContractMock } from "../../mocks/integrations/ConvexTokenRewardContractMock.sol";

import { Tokens } from "../../config/Tokens.sol";
import { USER, CONFIGURATOR } from "../../lib/constants.sol";

import "@gearbox-protocol/core-v2/contracts/test/lib/test.sol";

contract ConvexV1ClaimZapAdapterTest is DSTest, ConvexAdapterHelper {
    address creditAccount;
    TokenRewardContractMock tokenRewardContractMock;

    function setUp() public {
        _setupConvexSuite(2);

        tokenTestSuite.mint(Tokens.DAI, USER, DAI_ACCOUNT_AMOUNT);
        ERC20Mock(curveLPToken).mint(USER, CURVE_LP_AMOUNT);

        // IERC20(tokenTestSuite.addressOf(Tokens.DAI)).approve(address(creditManager), type(uint256).max);

        (creditAccount, ) = _openTestCreditAccount();
        addCollateral(curveLPToken, CURVE_LP_AMOUNT);

        evm.startPrank(USER);
        boosterAdapter.deposit(0, CURVE_LP_AMOUNT, false);
        basePoolAdapter.stakeAll();
        evm.stopPrank();

        basePoolMock.addRewardAmount(REWARD_AMOUNT);
        extraPoolMock1.addRewardAmount(REWARD_AMOUNT1);
        extraPoolMock2.addRewardAmount(REWARD_AMOUNT2);

        tokenRewardContractMock = new TokenRewardContractMock(
            address(basePoolMock),
            address(boosterMock)
        );
        tokenRewardContractMock.addRewardAmount(
            tokenTestSuite.addressOf(Tokens.USDT),
            REWARD_AMOUNT1
        );
        tokenRewardContractMock.addRewardAmount(
            tokenTestSuite.addressOf(Tokens.LINK),
            REWARD_AMOUNT2
        );
    }

    function _setUpZeroExtras() public {
        _setupConvexSuite(0);

        tokenTestSuite.mint(Tokens.DAI, USER, DAI_ACCOUNT_AMOUNT);
        ERC20Mock(curveLPToken).mint(USER, CURVE_LP_AMOUNT);

        // IERC20(tokenTestSuite.addressOf(Tokens.DAI)).approve(address(creditManager), type(uint256).max);

        (creditAccount, ) = _openTestCreditAccount();
        addCollateral(curveLPToken, CURVE_LP_AMOUNT);

        evm.startPrank(USER);
        boosterAdapter.deposit(0, CURVE_LP_AMOUNT, false);
        basePoolAdapter.stakeAll();
        evm.stopPrank();

        basePoolMock.addRewardAmount(REWARD_AMOUNT);

        tokenRewardContractMock = new TokenRewardContractMock(
            address(basePoolMock),
            address(boosterMock)
        );
        tokenRewardContractMock.addRewardAmount(
            tokenTestSuite.addressOf(Tokens.USDT),
            REWARD_AMOUNT1
        );
        tokenRewardContractMock.addRewardAmount(
            tokenTestSuite.addressOf(Tokens.LINK),
            REWARD_AMOUNT2
        );
    }

    ///
    /// TESTS
    ///

    /// @dev [ACVX1_Z_01]: claimRewards works correctly and emits events
    function test_ACVX1_Z_01_claimRewards_works_correctly() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();

            address usdt = tokenTestSuite.addressOf(Tokens.USDT);
            address link = tokenTestSuite.addressOf(Tokens.LINK);

            address[] memory rewardContracts = new address[](1);
            address[] memory extraRewardContracts;
            address[] memory tokenRewardContracts = new address[](2);
            address[] memory tokenRewardTokens = new address[](2);

            rewardContracts[0] = address(basePoolMock);

            tokenRewardContracts[0] = address(tokenRewardContractMock);
            tokenRewardContracts[1] = address(tokenRewardContractMock);

            tokenRewardTokens[0] = usdt;
            tokenRewardTokens[1] = link;

            bytes memory expectedCallData = abi.encodeWithSignature(
                "claimRewards(address[],address[],address[],address[],uint256,uint256,uint256,uint256,uint256)",
                rewardContracts,
                extraRewardContracts,
                tokenRewardContracts,
                tokenRewardTokens,
                0,
                0,
                0,
                0,
                0
            );

            if (multicall) {
                executeOneLineMulticall(
                    address(claimZapAdapter),
                    expectedCallData
                );
            } else {
                evm.prank(USER);
                claimZapAdapter.claimRewards(
                    rewardContracts,
                    extraRewardContracts,
                    tokenRewardContracts,
                    tokenRewardTokens,
                    0,
                    0,
                    0,
                    0,
                    0
                );
            }

            expectBalance(crv, creditAccount, REWARD_AMOUNT);
            expectBalance(cvx, creditAccount, REWARD_AMOUNT);

            expectBalance(extraRewardToken1, creditAccount, REWARD_AMOUNT1);
            expectBalance(extraRewardToken2, creditAccount, REWARD_AMOUNT2);

            expectBalance(usdt, creditAccount, REWARD_AMOUNT1);
            expectBalance(link, creditAccount, REWARD_AMOUNT2);

            expectTokenIsEnabled(crv, true);
            expectTokenIsEnabled(cvx, true);
            expectTokenIsEnabled(extraRewardToken1, true);
            expectTokenIsEnabled(extraRewardToken2, true);
            expectTokenIsEnabled(usdt, true);
            expectTokenIsEnabled(link, true);
        }
    }

    /// @dev [ACVX1_Z_02]: claimRewards claims from individual extra pools correctly
    function test_ACVX1_Z_02_claimRewards_supports_claiming_from_extra_pools()
        public
    {
        for (
            uint256 extraRewardsCase;
            extraRewardsCase <= 2;
            extraRewardsCase++
        ) {
            for (uint256 m = 0; m < 2; m++) {
                bool multicall = m != 0;

                setUp();
                address[] memory rewardContracts;
                address[] memory extraRewardContracts;
                address[] memory tokenRewardContracts;
                address[] memory tokenRewardTokens;
                address[] memory enabledTokens;

                if (extraRewardsCase == 0) {
                    extraRewardContracts = new address[](1);
                    extraRewardContracts[0] = address(extraPoolMock1);
                    enabledTokens = new address[](1);
                    enabledTokens[0] = extraRewardToken1;
                } else if (extraRewardsCase == 1) {
                    extraRewardContracts = new address[](1);
                    extraRewardContracts[0] = address(extraPoolMock2);
                    enabledTokens = new address[](1);
                    enabledTokens[0] = extraRewardToken2;
                } else if (extraRewardsCase == 2) {
                    extraRewardContracts = new address[](2);
                    extraRewardContracts[0] = address(extraPoolMock1);
                    extraRewardContracts[1] = address(extraPoolMock2);
                    enabledTokens = new address[](2);
                    enabledTokens[0] = extraRewardToken1;
                    enabledTokens[1] = extraRewardToken2;
                }

                bytes memory expectedCallData = abi.encodeWithSignature(
                    "claimRewards(address[],address[],address[],address[],uint256,uint256,uint256,uint256,uint256)",
                    rewardContracts,
                    extraRewardContracts,
                    tokenRewardContracts,
                    tokenRewardTokens,
                    0,
                    0,
                    0,
                    0,
                    0
                );

                // expectClaimZapStackCalls(
                //     USER,
                //     expectedCallData,
                //     enabledTokens,
                //     multicall
                // );

                if (multicall) {
                    executeOneLineMulticall(
                        address(claimZapAdapter),
                        expectedCallData
                    );
                } else {
                    evm.prank(USER);
                    claimZapAdapter.claimRewards(
                        rewardContracts,
                        extraRewardContracts,
                        tokenRewardContracts,
                        tokenRewardTokens,
                        0,
                        0,
                        0,
                        0,
                        0
                    );
                }
                expectBalance(crv, creditAccount, 0);

                expectBalance(cvx, creditAccount, 0);

                expectBalance(
                    extraRewardToken1,
                    creditAccount,
                    (extraRewardsCase == 0 || extraRewardsCase == 2)
                        ? REWARD_AMOUNT1
                        : 0
                );
                expectBalance(
                    extraRewardToken2,
                    creditAccount,
                    (extraRewardsCase == 1 || extraRewardsCase == 2)
                        ? REWARD_AMOUNT2
                        : 0
                );

                expectTokenIsEnabled(crv, false);
                expectTokenIsEnabled(cvx, false);

                expectTokenIsEnabled(
                    extraRewardToken1,
                    (extraRewardsCase == 0 || extraRewardsCase == 2)
                );
                expectTokenIsEnabled(
                    extraRewardToken2,
                    (extraRewardsCase == 1 || extraRewardsCase == 2)
                );
            }
        }
    }

    /// @dev [ACVX1_Z_03]: claimRewards ignores extra parameters
    function test_ACVX1_Z_03_claimRewards_ignores_options() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();
            address[] memory rewardContracts;
            address[] memory extraRewardContracts;
            address[] memory tokenRewardContracts;
            address[] memory tokenRewardTokens;

            if (multicall) {
                executeOneLineMulticall(
                    address(claimZapAdapter),
                    abi.encodeWithSignature(
                        "claimRewards(address[],address[],address[],address[],uint256,uint256,uint256,uint256,uint256)",
                        rewardContracts,
                        extraRewardContracts,
                        tokenRewardContracts,
                        tokenRewardTokens,
                        REWARD_AMOUNT,
                        2 * REWARD_AMOUNT,
                        3 * REWARD_AMOUNT,
                        4 * REWARD_AMOUNT,
                        1
                    )
                );
            } else {
                evm.prank(USER);
                // The mock target contract reverts if the adapter passes non-zero options
                // The correct behavior is adapter replacing options with 0's
                claimZapAdapter.claimRewards(
                    rewardContracts,
                    extraRewardContracts,
                    tokenRewardContracts,
                    tokenRewardTokens,
                    REWARD_AMOUNT,
                    2 * REWARD_AMOUNT,
                    3 * REWARD_AMOUNT,
                    4 * REWARD_AMOUNT,
                    1
                );
            }
        }
    }

    /// @dev [ACVX1_Z_04]: claimRewards does nothing for tokens that weren't passed with the corresponding tokenRewardContract
    function test_ACVX1_Z_04_claimRewards_only_covers_tokens_with_corresponding_contract()
        public
    {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();

            address usdt = tokenTestSuite.addressOf(Tokens.USDT);
            address link = tokenTestSuite.addressOf(Tokens.LINK);

            address[] memory rewardContracts;
            address[] memory extraRewardContracts;
            address[] memory tokenRewardContracts = new address[](1);
            address[] memory tokenRewardTokens = new address[](2);

            tokenRewardContracts[0] = address(tokenRewardContractMock);

            tokenRewardTokens[0] = usdt;
            tokenRewardTokens[1] = link;

            if (multicall) {
                executeOneLineMulticall(
                    address(claimZapAdapter),
                    abi.encodeWithSignature(
                        "claimRewards(address[],address[],address[],address[],uint256,uint256,uint256,uint256,uint256)",
                        rewardContracts,
                        extraRewardContracts,
                        tokenRewardContracts,
                        tokenRewardTokens,
                        0,
                        0,
                        0,
                        0,
                        0
                    )
                );
            } else {
                evm.prank(USER);
                claimZapAdapter.claimRewards(
                    rewardContracts,
                    extraRewardContracts,
                    tokenRewardContracts,
                    tokenRewardTokens,
                    0,
                    0,
                    0,
                    0,
                    0
                );
            }

            expectBalance(usdt, creditAccount, REWARD_AMOUNT1);
            expectBalance(link, creditAccount, 0);

            expectTokenIsEnabled(usdt, true);
            expectTokenIsEnabled(link, false);
        }
    }

    /// @dev [ACVX1_Z_05]: claimRewards should not fail for pool with less than 2 extras
    function test_ACVX1_Z_05_claimRewards_does_not_fail_for_no_extras() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            _setUpZeroExtras();

            address usdt = tokenTestSuite.addressOf(Tokens.USDT);
            address link = tokenTestSuite.addressOf(Tokens.LINK);

            address[] memory rewardContracts = new address[](1);
            address[] memory extraRewardContracts;
            address[] memory tokenRewardContracts = new address[](2);
            address[] memory tokenRewardTokens = new address[](2);

            rewardContracts[0] = address(basePoolMock);

            tokenRewardContracts[0] = address(tokenRewardContractMock);
            tokenRewardContracts[1] = address(tokenRewardContractMock);

            tokenRewardTokens[0] = usdt;
            tokenRewardTokens[1] = link;

            bytes memory expectedCallData = abi.encodeWithSignature(
                "claimRewards(address[],address[],address[],address[],uint256,uint256,uint256,uint256,uint256)",
                rewardContracts,
                extraRewardContracts,
                tokenRewardContracts,
                tokenRewardTokens,
                0,
                0,
                0,
                0,
                0
            );

            if (multicall) {
                executeOneLineMulticall(
                    address(claimZapAdapter),
                    expectedCallData
                );
            } else {
                evm.prank(USER);
                claimZapAdapter.claimRewards(
                    rewardContracts,
                    extraRewardContracts,
                    tokenRewardContracts,
                    tokenRewardTokens,
                    0,
                    0,
                    0,
                    0,
                    0
                );
            }

            expectBalance(crv, creditAccount, REWARD_AMOUNT);
            expectBalance(cvx, creditAccount, REWARD_AMOUNT);

            expectBalance(usdt, creditAccount, REWARD_AMOUNT1);
            expectBalance(link, creditAccount, REWARD_AMOUNT2);

            expectTokenIsEnabled(crv, true);
            expectTokenIsEnabled(cvx, true);
            expectTokenIsEnabled(usdt, true);
            expectTokenIsEnabled(link, true);
        }
    }
}
