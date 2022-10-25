// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICreditFacade } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacade.sol";
import { IBaseRewardPool } from "../../../integrations/convex/IBaseRewardPool.sol";
import { IBooster } from "../../../integrations/convex/IBooster.sol";
import { IConvexV1BaseRewardPoolAdapter } from "../../../interfaces/adapters/convex/IConvexV1BaseRewardPoolAdapter.sol";

import { Tokens } from "../../config/Tokens.sol";
import { Contracts } from "../../config/SupportedContracts.sol";

import { MultiCall } from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import { CreditFacadeCalls, CreditFacadeMulticaller } from "@gearbox-protocol/core-v2/contracts/multicall/CreditFacadeCalls.sol";
import { AddressList } from "@gearbox-protocol/core-v2/contracts/libraries/AddressList.sol";
// TEST
import "@gearbox-protocol/core-v2/contracts/test/lib/constants.sol";

// SUITES
import { LiveEnvTestSuite } from "../../suites/LiveEnvTestSuite.sol";
import { LiveEnvHelper } from "../../suites/LiveEnvHelper.sol";
import { BalanceComparator, BalanceBackup } from "../../helpers/BalanceComparator.sol";

contract Live_ConvexEquivalenceTest is DSTest, LiveEnvHelper {
    using CreditFacadeCalls for CreditFacadeMulticaller;
    using AddressList for address[];

    string[14] stages = [
        "after_booster_deposit_no_staking",
        "after_booster_depositAll_no_staking",
        "after_basePool_stake",
        "after_basePool_stakeAll",
        "after_basePool_getReward_no_extras",
        "after_basePool_getReward_with_extras",
        "after_basePool_withdraw",
        "after_basePool_withdrawAll",
        "after_booster_withdraw",
        "after_booster_withdrawAll",
        "after_booster_deposit_with_staking",
        "after_booster_depositAll_with_staking",
        "after_basePool_withdrawAndUnwrap",
        "after_basePool_withdrawAllAndUnwrap"
    ];

    Contracts[6] convexPools = [
        Contracts.CONVEX_3CRV_POOL,
        Contracts.CONVEX_GUSD_POOL,
        Contracts.CONVEX_SUSD_POOL,
        Contracts.CONVEX_STECRV_POOL,
        Contracts.CONVEX_FRAX3CRV_POOL,
        Contracts.CONVEX_LUSD3CRV_POOL
    ];

    string[] _stages;

    function setUp() public liveOnly {
        _setUp();

        /// @notice Sets comparator for this equivalence test

        uint256 len = stages.length;
        _stages = new string[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _stages[i] = stages[i];
            }
        }
    }

    /// HELPER

    function compareBehavior(
        address boosterAddress,
        address basePoolAddress,
        address accountToSaveBalances,
        BalanceComparator comparator
    ) internal {
        IBooster booster = IBooster(boosterAddress);
        IBaseRewardPool basePool = IBaseRewardPool(basePoolAddress);

        uint256 pid = basePool.pid();

        evm.prank(USER);
        booster.deposit(pid, WAD, false);
        comparator.takeSnapshot(
            "after_booster_deposit_no_staking",
            accountToSaveBalances
        );

        evm.prank(USER);
        booster.depositAll(pid, false);
        comparator.takeSnapshot(
            "after_booster_depositAll_no_staking",
            accountToSaveBalances
        );

        evm.prank(USER);
        basePool.stake(WAD);
        comparator.takeSnapshot("after_basePool_stake", accountToSaveBalances);

        evm.prank(USER);
        basePool.stakeAll();
        comparator.takeSnapshot(
            "after_basePool_stakeAll",
            accountToSaveBalances
        );

        evm.warp(block.timestamp + 24 * 60 * 60);

        evm.prank(USER);
        basePool.getReward(accountToSaveBalances, false);
        comparator.takeSnapshot(
            "after_basePool_getReward_no_extras",
            accountToSaveBalances
        );

        evm.warp(block.timestamp + 24 * 60 * 60);

        evm.prank(USER);
        basePool.getReward(accountToSaveBalances, true);
        comparator.takeSnapshot(
            "after_basePool_getReward_with_extras",
            accountToSaveBalances
        );

        evm.warp(block.timestamp + 24 * 60 * 60);

        evm.prank(USER);
        basePool.withdraw(WAD, true);
        comparator.takeSnapshot(
            "after_basePool_withdraw",
            accountToSaveBalances
        );

        evm.warp(block.timestamp + 24 * 60 * 60);

        evm.prank(USER);
        basePool.withdrawAll(true);
        comparator.takeSnapshot(
            "after_basePool_withdrawAll",
            accountToSaveBalances
        );

        evm.prank(USER);
        booster.withdraw(pid, WAD);
        comparator.takeSnapshot(
            "after_booster_withdraw",
            accountToSaveBalances
        );

        evm.prank(USER);
        booster.withdrawAll(pid);
        comparator.takeSnapshot(
            "after_booster_withdrawAll",
            accountToSaveBalances
        );

        evm.prank(USER);
        booster.deposit(pid, WAD, true);
        comparator.takeSnapshot(
            "after_booster_deposit_with_staking",
            accountToSaveBalances
        );

        evm.prank(USER);
        booster.depositAll(pid, true);
        comparator.takeSnapshot(
            "after_booster_depositAll_with_staking",
            accountToSaveBalances
        );

        evm.warp(block.timestamp + 24 * 60 * 60);

        evm.prank(USER);
        basePool.withdrawAndUnwrap(WAD, true);
        comparator.takeSnapshot(
            "after_basePool_withdrawAndUnwrap",
            accountToSaveBalances
        );

        evm.warp(block.timestamp + 24 * 60 * 60);

        evm.prank(USER);
        basePool.withdrawAllAndUnwrap(true);
        comparator.takeSnapshot(
            "after_basePool_withdrawAllAndUnwrap",
            accountToSaveBalances
        );
    }

    function openCreditAccountWithUnderlying(address token, uint256 amount)
        internal
        returns (address creditAccount)
    {
        ICreditFacade creditFacade = lts.creditFacades(Tokens.DAI);

        (uint256 minAmount, ) = creditFacade.limits();

        tokenTestSuite.mint(Tokens.DAI, USER, minAmount);

        // Approve tokens
        tokenTestSuite.approve(
            Tokens.DAI,
            USER,
            address(lts.creditManagers(Tokens.DAI))
        );

        evm.startPrank(USER);
        creditFacade.openCreditAccountMulticall(
            minAmount,
            USER,
            multicallBuilder(
                CreditFacadeMulticaller(address(creditFacade)).addCollateral(
                    USER,
                    tokenTestSuite.addressOf(Tokens.DAI),
                    minAmount
                )
            ),
            0
        );

        evm.stopPrank();

        creditAccount = lts.creditManagers(Tokens.DAI).getCreditAccountOrRevert(
                USER
            );

        tokenTestSuite.mint(token, creditAccount, amount);
    }

    function prepareComparator(address basePoolAdapter)
        internal
        returns (BalanceComparator comparator)
    {
        address[] memory tokensToTrack = new address[](7);

        tokensToTrack[0] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter)
            .curveLPtoken();
        tokensToTrack[1] = address(
            IConvexV1BaseRewardPoolAdapter(basePoolAdapter).stakingToken()
        );
        tokensToTrack[2] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter)
            .stakedPhantomToken();
        tokensToTrack[3] = address(
            IConvexV1BaseRewardPoolAdapter(basePoolAdapter).rewardToken()
        );
        tokensToTrack[4] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter)
            .cvx();
        tokensToTrack[5] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter)
            .extraReward1();
        tokensToTrack[6] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter)
            .extraReward2();

        tokensToTrack = tokensToTrack.trim();

        Tokens[] memory _tokensToTrack = new Tokens[](tokensToTrack.length);

        for (uint256 j = 0; j < tokensToTrack.length; ++j) {
            _tokensToTrack[j] = tokenTestSuite.tokenIndexes(tokensToTrack[j]);
        }

        comparator = new BalanceComparator(
            _stages,
            _tokensToTrack,
            tokenTestSuite
        );
    }

    /// @dev [L-CVXET-1]: convex adapters and original contracts work identically
    function test_live_CVXET_01_Convex_adapters_and_original_contracts_are_equivalent()
        public
        liveOnly
    {
        for (uint256 i = 0; i < convexPools.length; ++i) {
            uint256 snapshot0 = evm.snapshot();
            uint256 snapshot1 = evm.snapshot();

            address basePoolAdapter = lts.getAdapter(
                Tokens.DAI,
                convexPools[i]
            );

            BalanceComparator comparator = prepareComparator(basePoolAdapter);

            tokenTestSuite.approve(
                IConvexV1BaseRewardPoolAdapter(basePoolAdapter).curveLPtoken(),
                USER,
                supportedContracts.addressOf(Contracts.CONVEX_BOOSTER)
            );

            tokenTestSuite.approve(
                address(
                    IConvexV1BaseRewardPoolAdapter(basePoolAdapter)
                        .stakingToken()
                ),
                USER,
                supportedContracts.addressOf(convexPools[i])
            );

            tokenTestSuite.mint(
                IConvexV1BaseRewardPoolAdapter(basePoolAdapter).curveLPtoken(),
                USER,
                3000 * WAD
            );

            compareBehavior(
                supportedContracts.addressOf(Contracts.CONVEX_BOOSTER),
                supportedContracts.addressOf(convexPools[i]),
                USER,
                comparator
            );

            BalanceBackup[] memory savedBalanceSnapshots = comparator
                .exportSnapshots(USER);

            evm.revertTo(snapshot1);

            comparator = prepareComparator(basePoolAdapter);

            address creditAccount = openCreditAccountWithUnderlying(
                IConvexV1BaseRewardPoolAdapter(basePoolAdapter).curveLPtoken(),
                3000 * WAD
            );

            compareBehavior(
                lts.getAdapter(Tokens.DAI, Contracts.CONVEX_BOOSTER),
                lts.getAdapter(Tokens.DAI, convexPools[i]),
                creditAccount,
                comparator
            );

            comparator.compareAllSnapshots(
                creditAccount,
                savedBalanceSnapshots
            );

            evm.revertTo(snapshot0);
        }
    }
}
