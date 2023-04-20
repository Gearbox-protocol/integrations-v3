// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacade} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacade.sol";
import {IBaseRewardPool} from "../../../integrations/convex/IBaseRewardPool.sol";
import {IRewards} from "../../../integrations/convex/IRewards.sol";
import {IBooster} from "../../../integrations/convex/IBooster.sol";
import {IConvexV1BaseRewardPoolAdapter} from "../../../interfaces/convex/IConvexV1BaseRewardPoolAdapter.sol";
import {
    ConvexV1_BaseRewardPoolCalls,
    ConvexV1_BaseRewardPoolMulticaller
} from "../../../multicall/convex/ConvexV1_BaseRewardPoolCalls.sol";
import {ConvexV1_BoosterCalls, ConvexV1_BoosterMulticaller} from "../../../multicall/convex/ConvexV1_BoosterCalls.sol";

import {Tokens} from "../../config/Tokens.sol";
import {Contracts} from "../../config/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import {
    CreditFacadeCalls,
    CreditFacadeMulticaller
} from "@gearbox-protocol/core-v2/contracts/multicall/CreditFacadeCalls.sol";
import {AddressList} from "@gearbox-protocol/core-v2/contracts/libraries/AddressList.sol";
// TEST
import "@gearbox-protocol/core-v2/contracts/test/lib/constants.sol";

// SUITES
import {LiveEnvTestSuite} from "../../suites/LiveEnvTestSuite.sol";
import {LiveEnvHelper} from "../../suites/LiveEnvHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../helpers/BalanceComparator.sol";

contract Live_ConvexEquivalenceTest is DSTest, LiveEnvHelper {
    using ConvexV1_BaseRewardPoolCalls for ConvexV1_BaseRewardPoolMulticaller;
    using ConvexV1_BoosterCalls for ConvexV1_BoosterMulticaller;
    using CreditFacadeCalls for CreditFacadeMulticaller;
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

    function _getTokensToTrack(address basePoolAdapter) internal view returns (Tokens[] memory tokensToTrack) {
        address targetContract = IConvexV1BaseRewardPoolAdapter(basePoolAdapter).targetContract();

        address[] memory _tokensToTrack = new address[](7);

        _tokensToTrack[0] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter).curveLPtoken();
        _tokensToTrack[1] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter).stakingToken();
        _tokensToTrack[2] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter).stakedPhantomToken();
        _tokensToTrack[3] = tokenTestSuite.addressOf(Tokens.CRV);
        _tokensToTrack[4] = tokenTestSuite.addressOf(Tokens.CVX);

        uint256 extraRewardLength = IBaseRewardPool(targetContract).extraRewardsLength();
        if (extraRewardLength >= 1) {
            _tokensToTrack[5] = IRewards(IBaseRewardPool(targetContract).extraRewards(0)).rewardToken();

            if (extraRewardLength >= 2) {
                _tokensToTrack[6] = IRewards(IBaseRewardPool(targetContract).extraRewards(1)).rewardToken();
            }
        }
        _tokensToTrack = _tokensToTrack.trim();

        tokensToTrack = new Tokens[](_tokensToTrack.length);

        for (uint256 j = 0; j < _tokensToTrack.length; ++j) {
            tokensToTrack[j] = tokenTestSuite.tokenIndexes(_tokensToTrack[j]);
        }
    }

    function compareBehavior(
        ICreditFacade creditFacade,
        address boosterAddress,
        address basePoolAddress,
        address accountToSaveBalances,
        bool adapters,
        BalanceComparator comparator
    ) internal {
        if (adapters) {
            ConvexV1_BoosterMulticaller booster = ConvexV1_BoosterMulticaller(boosterAddress);
            ConvexV1_BaseRewardPoolMulticaller basePool = ConvexV1_BaseRewardPoolMulticaller(basePoolAddress);

            uint256 pid = IBaseRewardPool((IConvexV1BaseRewardPoolAdapter(basePoolAddress).targetContract())).pid();

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(booster.deposit(pid, WAD, false)));
            comparator.takeSnapshot("after_booster_deposit_no_staking", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(booster.depositAll(pid, false)));
            comparator.takeSnapshot("after_booster_depositAll_no_staking", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(basePool.stake(WAD)));
            comparator.takeSnapshot("after_basePool_stake", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(basePool.stakeAll()));
            comparator.takeSnapshot("after_basePool_stakeAll", accountToSaveBalances);

            evm.warp(block.timestamp + 24 * 60 * 60);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(basePool.getReward()));
            comparator.takeSnapshot("after_basePool_getReward_with_extras", accountToSaveBalances);

            evm.warp(block.timestamp + 24 * 60 * 60);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(basePool.withdraw(WAD, true)));
            comparator.takeSnapshot("after_basePool_withdraw", accountToSaveBalances);

            evm.warp(block.timestamp + 24 * 60 * 60);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(basePool.withdrawAll(true)));
            comparator.takeSnapshot("after_basePool_withdrawAll", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(booster.withdraw(pid, WAD)));
            comparator.takeSnapshot("after_booster_withdraw", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(booster.withdrawAll(pid)));
            comparator.takeSnapshot("after_booster_withdrawAll", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(booster.deposit(pid, WAD, true)));
            comparator.takeSnapshot("after_booster_deposit_with_staking", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(booster.depositAll(pid, true)));
            comparator.takeSnapshot("after_booster_depositAll_with_staking", accountToSaveBalances);

            evm.warp(block.timestamp + 24 * 60 * 60);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(basePool.withdrawAndUnwrap(WAD, true)));
            comparator.takeSnapshot("after_basePool_withdrawAndUnwrap", accountToSaveBalances);

            evm.warp(block.timestamp + 24 * 60 * 60);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(basePool.withdrawAllAndUnwrap(true)));
            comparator.takeSnapshot("after_basePool_withdrawAllAndUnwrap", accountToSaveBalances);
        } else {
            IBooster booster = IBooster(boosterAddress);
            IBaseRewardPool basePool = IBaseRewardPool(basePoolAddress);

            uint256 pid = basePool.pid();

            evm.prank(USER);
            booster.deposit(pid, WAD, false);
            comparator.takeSnapshot("after_booster_deposit_no_staking", accountToSaveBalances);

            evm.prank(USER);
            booster.depositAll(pid, false);
            comparator.takeSnapshot("after_booster_depositAll_no_staking", accountToSaveBalances);

            evm.prank(USER);
            basePool.stake(WAD);
            comparator.takeSnapshot("after_basePool_stake", accountToSaveBalances);

            evm.prank(USER);
            basePool.stakeAll();
            comparator.takeSnapshot("after_basePool_stakeAll", accountToSaveBalances);

            evm.warp(block.timestamp + 24 * 60 * 60);

            evm.prank(USER);
            basePool.getReward();
            comparator.takeSnapshot("after_basePool_getReward_with_extras", accountToSaveBalances);

            evm.warp(block.timestamp + 24 * 60 * 60);

            evm.prank(USER);
            basePool.withdraw(WAD, true);
            comparator.takeSnapshot("after_basePool_withdraw", accountToSaveBalances);

            evm.warp(block.timestamp + 24 * 60 * 60);

            evm.prank(USER);
            basePool.withdrawAll(true);
            comparator.takeSnapshot("after_basePool_withdrawAll", accountToSaveBalances);

            evm.prank(USER);
            booster.withdraw(pid, WAD);
            comparator.takeSnapshot("after_booster_withdraw", accountToSaveBalances);

            evm.prank(USER);
            booster.withdrawAll(pid);
            comparator.takeSnapshot("after_booster_withdrawAll", accountToSaveBalances);

            evm.prank(USER);
            booster.deposit(pid, WAD, true);
            comparator.takeSnapshot("after_booster_deposit_with_staking", accountToSaveBalances);

            evm.prank(USER);
            booster.depositAll(pid, true);
            comparator.takeSnapshot("after_booster_depositAll_with_staking", accountToSaveBalances);

            evm.warp(block.timestamp + 24 * 60 * 60);

            evm.prank(USER);
            basePool.withdrawAndUnwrap(WAD, true);
            comparator.takeSnapshot("after_basePool_withdrawAndUnwrap", accountToSaveBalances);

            evm.warp(block.timestamp + 24 * 60 * 60);

            evm.prank(USER);
            basePool.withdrawAllAndUnwrap(true);
            comparator.takeSnapshot("after_basePool_withdrawAllAndUnwrap", accountToSaveBalances);
        }
    }

    function openCreditAccountWithUnderlying(
        ICreditFacade creditFacade,
        address token,
        uint256 accountAmount,
        uint256 mintAmount,
        address basePoolAdapter
    ) internal returns (address creditAccount) {
        tokenTestSuite.mint(creditFacade.underlying(), USER, accountAmount);

        // Approve tokens
        tokenTestSuite.approve(creditFacade.underlying(), USER, address(creditFacade.creditManager()));

        evm.startPrank(USER);
        creditFacade.openCreditAccountMulticall(
            accountAmount,
            USER,
            multicallBuilder(
                CreditFacadeMulticaller(address(creditFacade)).addCollateral(
                    USER, creditFacade.underlying(), accountAmount
                )
            ),
            0
        );

        evm.stopPrank();

        creditAccount = creditFacade.creditManager().getCreditAccountOrRevert(USER);

        tokenTestSuite.mint(token, creditAccount, mintAmount);

        tokenTestSuite.alignBalances(_getTokensToTrack(basePoolAdapter), creditAccount, USER);
    }

    function prepareComparator(address basePoolAdapter) internal returns (BalanceComparator comparator) {
        comparator = new BalanceComparator(
            _stages,
            _getTokensToTrack(basePoolAdapter),
            tokenTestSuite
        );
    }

    /// @dev [L-CVXET-1]: convex adapters and original contracts work identically
    function test_live_CVXET_01_Convex_adapters_and_original_contracts_are_equivalent() public liveOnly {
        (, ICreditFacade creditFacade,, uint256 accountAmount) = lts.getActiveCM();

        for (uint256 i = 0; i < convexPools.length; ++i) {
            uint256 snapshot0 = evm.snapshot();

            address basePoolAdapter = lts.getAdapter(address(creditFacade.creditManager()), convexPools[i]);

            address creditAccount = openCreditAccountWithUnderlying(
                creditFacade,
                IConvexV1BaseRewardPoolAdapter(basePoolAdapter).curveLPtoken(),
                accountAmount,
                3000 * WAD,
                lts.getAdapter(address(creditFacade.creditManager()), convexPools[i])
            );

            uint256 snapshot1 = evm.snapshot();

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

            compareBehavior(
                creditFacade,
                supportedContracts.addressOf(Contracts.CONVEX_BOOSTER),
                supportedContracts.addressOf(convexPools[i]),
                USER,
                false,
                comparator
            );

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(USER);

            evm.revertTo(snapshot1);

            comparator = prepareComparator(basePoolAdapter);

            compareBehavior(
                creditFacade,
                lts.getAdapter(address(creditFacade.creditManager()), Contracts.CONVEX_BOOSTER),
                lts.getAdapter(address(creditFacade.creditManager()), convexPools[i]),
                creditAccount,
                true,
                comparator
            );

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);

            evm.revertTo(snapshot0);
        }
    }
}
