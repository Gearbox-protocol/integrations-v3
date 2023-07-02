// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IBaseRewardPool} from "../../../../integrations/convex/IBaseRewardPool.sol";
import {IRewards} from "../../../../integrations/convex/IRewards.sol";
import {IBooster} from "../../../../integrations/convex/IBooster.sol";
import {IConvexV1BaseRewardPoolAdapter} from "../../../../interfaces/convex/IConvexV1BaseRewardPoolAdapter.sol";

import {
    ConvexV1_BoosterCalls, ConvexV1_BoosterMulticaller
} from "../../../../multicall/convex/ConvexV1_BoosterCalls.sol";

import {Tokens} from "../../../config/Tokens.sol";
import {Contracts} from "../../../config/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import {AddressList} from "@gearbox-protocol/core-v3/contracts/test/lib/AddressList.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES
import {LiveEnvTestSuite} from "../../../suites/LiveEnvTestSuite.sol";
import {LiveEnvHelper} from "../../../suites/LiveEnvHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_ConvexEquivalenceTest is Test, LiveEnvHelper {
    using ConvexV1_BaseRewardPoolCalls for ConvexV1_BaseRewardPoolMulticaller;
    using ConvexV1_BoosterCalls for ConvexV1_BoosterMulticaller;
    using CreditFacadeV3Calls for CreditFacadeV3Multicaller;
    using AddressList for address[];

    string[14] stages = [
        "after_booster_deposit_no_staking",
        "after_booster_depositAll_no_staking",
        "after_basePool_stake",
        "after_basePool_stakeAll",
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
        bool adapters,
        BalanceComparator comparator
    ) internal {
        if (adapters) {
            ICreditFacadeV3 creditFacade = lts.creditFacades(Tokens.DAI);
            ConvexV1_BoosterMulticaller booster = ConvexV1_BoosterMulticaller(boosterAddress);
            ConvexV1_BaseRewardPoolMulticaller basePool = ConvexV1_BaseRewardPoolMulticaller(basePoolAddress);

            uint256 pid = IBaseRewardPool((IConvexV1BaseRewardPoolAdapter(basePoolAddress).targetContract())).pid();

            vm.prank(USER);
            creditFacade.multicall(multicallBuilder(booster.deposit(pid, WAD, false)));
            comparator.takeSnapshot("after_booster_deposit_no_staking", accountToSaveBalances);

            vm.prank(USER);
            creditFacade.multicall(multicallBuilder(booster.depositAll(pid, false)));
            comparator.takeSnapshot("after_booster_depositAll_no_staking", accountToSaveBalances);

            vm.prank(USER);
            creditFacade.multicall(multicallBuilder(basePool.stake(WAD)));
            comparator.takeSnapshot("after_basePool_stake", accountToSaveBalances);

            vm.prank(USER);
            creditFacade.multicall(multicallBuilder(basePool.stakeAll()));
            comparator.takeSnapshot("after_basePool_stakeAll", accountToSaveBalances);

            vm.warp(block.timestamp + 24 * 60 * 60);

            vm.prank(USER);
            creditFacade.multicall(multicallBuilder(basePool.getReward()));
            comparator.takeSnapshot("after_basePool_getReward_with_extras", accountToSaveBalances);

            vm.warp(block.timestamp + 24 * 60 * 60);

            vm.prank(USER);
            creditFacade.multicall(multicallBuilder(basePool.withdraw(WAD, true)));
            comparator.takeSnapshot("after_basePool_withdraw", accountToSaveBalances);

            vm.warp(block.timestamp + 24 * 60 * 60);

            vm.prank(USER);
            creditFacade.multicall(multicallBuilder(basePool.withdrawAll(true)));
            comparator.takeSnapshot("after_basePool_withdrawAll", accountToSaveBalances);

            vm.prank(USER);
            creditFacade.multicall(multicallBuilder(booster.withdraw(pid, WAD)));
            comparator.takeSnapshot("after_booster_withdraw", accountToSaveBalances);

            vm.prank(USER);
            creditFacade.multicall(multicallBuilder(booster.withdrawAll(pid)));
            comparator.takeSnapshot("after_booster_withdrawAll", accountToSaveBalances);

            vm.prank(USER);
            creditFacade.multicall(multicallBuilder(booster.deposit(pid, WAD, true)));
            comparator.takeSnapshot("after_booster_deposit_with_staking", accountToSaveBalances);

            vm.prank(USER);
            creditFacade.multicall(multicallBuilder(booster.depositAll(pid, true)));
            comparator.takeSnapshot("after_booster_depositAll_with_staking", accountToSaveBalances);

            vm.warp(block.timestamp + 24 * 60 * 60);

            vm.prank(USER);
            creditFacade.multicall(multicallBuilder(basePool.withdrawAndUnwrap(WAD, true)));
            comparator.takeSnapshot("after_basePool_withdrawAndUnwrap", accountToSaveBalances);

            vm.warp(block.timestamp + 24 * 60 * 60);

            vm.prank(USER);
            creditFacade.multicall(multicallBuilder(basePool.withdrawAllAndUnwrap(true)));
            comparator.takeSnapshot("after_basePool_withdrawAllAndUnwrap", accountToSaveBalances);
        } else {
            IBooster booster = IBooster(boosterAddress);
            IBaseRewardPool basePool = IBaseRewardPool(basePoolAddress);

            uint256 pid = basePool.pid();

            vm.prank(USER);
            booster.deposit(pid, WAD, false);
            comparator.takeSnapshot("after_booster_deposit_no_staking", accountToSaveBalances);

            vm.prank(USER);
            booster.depositAll(pid, false);
            comparator.takeSnapshot("after_booster_depositAll_no_staking", accountToSaveBalances);

            vm.prank(USER);
            basePool.stake(WAD);
            comparator.takeSnapshot("after_basePool_stake", accountToSaveBalances);

            vm.prank(USER);
            basePool.stakeAll();
            comparator.takeSnapshot("after_basePool_stakeAll", accountToSaveBalances);

            vm.warp(block.timestamp + 24 * 60 * 60);

            vm.prank(USER);
            basePool.getReward();
            comparator.takeSnapshot("after_basePool_getReward_with_extras", accountToSaveBalances);

            vm.warp(block.timestamp + 24 * 60 * 60);

            vm.prank(USER);
            basePool.withdraw(WAD, true);
            comparator.takeSnapshot("after_basePool_withdraw", accountToSaveBalances);

            vm.warp(block.timestamp + 24 * 60 * 60);

            vm.prank(USER);
            basePool.withdrawAll(true);
            comparator.takeSnapshot("after_basePool_withdrawAll", accountToSaveBalances);

            vm.prank(USER);
            booster.withdraw(pid, WAD);
            comparator.takeSnapshot("after_booster_withdraw", accountToSaveBalances);

            vm.prank(USER);
            booster.withdrawAll(pid);
            comparator.takeSnapshot("after_booster_withdrawAll", accountToSaveBalances);

            vm.prank(USER);
            booster.deposit(pid, WAD, true);
            comparator.takeSnapshot("after_booster_deposit_with_staking", accountToSaveBalances);

            vm.prank(USER);
            booster.depositAll(pid, true);
            comparator.takeSnapshot("after_booster_depositAll_with_staking", accountToSaveBalances);

            vm.warp(block.timestamp + 24 * 60 * 60);

            vm.prank(USER);
            basePool.withdrawAndUnwrap(WAD, true);
            comparator.takeSnapshot("after_basePool_withdrawAndUnwrap", accountToSaveBalances);

            vm.warp(block.timestamp + 24 * 60 * 60);

            vm.prank(USER);
            basePool.withdrawAllAndUnwrap(true);
            comparator.takeSnapshot("after_basePool_withdrawAllAndUnwrap", accountToSaveBalances);
        }
    }

    function openCreditAccountWithUnderlying(address token, uint256 amount) internal returns (address creditAccount) {
        ICreditFacadeV3 creditFacade = lts.creditFacades(Tokens.DAI);

        (uint256 minAmount,) = creditFacade.limits();

        tokenTestSuite.mint(Tokens.DAI, USER, minAmount);

        // Approve tokens
        tokenTestSuite.approve(Tokens.DAI, USER, address(lts.CreditManagerV3s(Tokens.DAI)));

        vm.startPrank(USER);
        creditFacade.openCreditAccountMulticall(
            minAmount,
            USER,
            multicallBuilder(
                CreditFacadeV3Multicaller(address(creditFacade)).addCollateral(
                    USER, tokenTestSuite.addressOf(Tokens.DAI), minAmount
                )
            ),
            0
        );

        vm.stopPrank();

        creditAccount = lts.CreditManagerV3s(Tokens.DAI).getCreditAccountOrRevert(USER);

        tokenTestSuite.mint(token, creditAccount, amount);
    }

    function prepareComparator(address basePoolAdapter) internal returns (BalanceComparator comparator) {
        address targetContract = IConvexV1BaseRewardPoolAdapter(basePoolAdapter).targetContract();

        address[] memory tokensToTrack = new address[](7);

        tokensToTrack[0] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter).curveLPtoken();
        tokensToTrack[1] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter).stakingToken();
        tokensToTrack[2] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter).stakedPhantomToken();
        tokensToTrack[3] = tokenTestSuite.addressOf(Tokens.CRV);
        tokensToTrack[4] = tokenTestSuite.addressOf(Tokens.CVX);

        uint256 extraRewardLength = IBaseRewardPool(targetContract).extraRewardsLength();
        if (extraRewardLength >= 1) {
            tokensToTrack[5] = IRewards(IBaseRewardPool(targetContract).extraRewards(0)).rewardToken();

            if (extraRewardLength >= 2) {
                tokensToTrack[6] = IRewards(IBaseRewardPool(targetContract).extraRewards(1)).rewardToken();
            }
        }
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
    function test_live_CVXET_01_Convex_adapters_and_original_contracts_are_equivalent() public liveOnly {
        for (uint256 i = 0; i < convexPools.length; ++i) {
            uint256 snapshot0 = vm.snapshot();
            uint256 snapshot1 = vm.snapshot();

            address basePoolAdapter = lts.getAdapter(Tokens.DAI, convexPools[i]);

            BalanceComparator comparator = prepareComparator(basePoolAdapter);

            tokenTestSuite.approve(
                IConvexV1BaseRewardPoolAdapter(basePoolAdapter).curveLPtoken(),
                USER,
                supportedContracts.addressOf(Contracts.CONVEX_BOOSTER)
            );

            tokenTestSuite.approve(
                address(IConvexV1BaseRewardPoolAdapter(basePoolAdapter).stakingToken()),
                USER,
                supportedContracts.addressOf(convexPools[i])
            );

            tokenTestSuite.mint(IConvexV1BaseRewardPoolAdapter(basePoolAdapter).curveLPtoken(), USER, 3000 * WAD);

            compareBehavior(
                supportedContracts.addressOf(Contracts.CONVEX_BOOSTER),
                supportedContracts.addressOf(convexPools[i]),
                USER,
                false,
                comparator
            );

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(USER);

            vm.revertTo(snapshot1);

            comparator = prepareComparator(basePoolAdapter);

            address creditAccount = openCreditAccountWithUnderlying(
                IConvexV1BaseRewardPoolAdapter(basePoolAdapter).curveLPtoken(), 3000 * WAD
            );

            compareBehavior(
                lts.getAdapter(Tokens.DAI, Contracts.CONVEX_BOOSTER),
                lts.getAdapter(Tokens.DAI, convexPools[i]),
                creditAccount,
                true,
                comparator
            );

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);

            vm.revertTo(snapshot0);
        }
    }
}
