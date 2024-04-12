// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {IConvexRewardPool_L2} from "../../../../integrations/convex/IConvexRewardPool_L2.sol";
import {IBooster_L2} from "../../../../integrations/convex/IBooster_L2.sol";
import {IRewards} from "../../../../integrations/convex/IRewards.sol";
import {IConvexL2RewardPoolAdapter} from "../../../../interfaces/convex/IConvexL2RewardPoolAdapter.sol";

import {
    ConvexL2_RewardPoolCalls,
    ConvexL2_RewardPoolMulticaller
} from "../../../multicall/convex/ConvexL2_RewardPoolCalls.sol";
import {ConvexL2_BoosterCalls, ConvexL2_BoosterMulticaller} from "../../../multicall/convex/ConvexL2_BoosterCalls.sol";
import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";

import {AddressList} from "@gearbox-protocol/core-v3/contracts/test/lib/AddressList.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

/// @notice This also includes Aura pools
contract Live_ConvexL2EquivalenceTest is LiveTestHelper {
    using AddressList for address[];
    using ConvexL2_RewardPoolCalls for ConvexL2_RewardPoolMulticaller;
    using ConvexL2_BoosterCalls for ConvexL2_BoosterMulticaller;

    string[5] stages = [
        "after_booster_deposit",
        "after_booster_depositDiff",
        "after_rewardPool_getReward",
        "after_rewardPool_withdraw",
        "after_rewardPool_withdrawDiff"
    ];

    string[] _stages;

    function setUp() public {
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
        address creditAccount,
        address boosterAddress,
        address basePoolAddress,
        bool adapters,
        BalanceComparator comparator
    ) internal {
        if (adapters) {
            uint256 pid =
                IConvexRewardPool_L2((IConvexL2RewardPoolAdapter(basePoolAddress).targetContract())).convexPoolId();
            ConvexL2_BoosterMulticaller booster = ConvexL2_BoosterMulticaller(boosterAddress);
            ConvexL2_RewardPoolMulticaller basePool = ConvexL2_RewardPoolMulticaller(basePoolAddress);

            vm.startPrank(USER);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(booster.deposit(pid, WAD)));
            comparator.takeSnapshot("after_booster_deposit", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(booster.depositDiff(pid, WAD)));
            comparator.takeSnapshot("after_booster_depositDiff", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(basePool.getReward()));
            comparator.takeSnapshot("after_rewardPool_getReward", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(basePool.withdraw(WAD, true)));
            comparator.takeSnapshot("after_rewardPool_withdraw", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(basePool.withdrawDiff(WAD, true)));
            comparator.takeSnapshot("after_rewardPool_withdrawDiff", creditAccount);

            vm.stopPrank();
        } else {
            IBooster_L2 booster = IBooster_L2(boosterAddress);
            IConvexRewardPool_L2 basePool = IConvexRewardPool_L2(basePoolAddress);

            uint256 pid = basePool.convexPoolId();

            (address crvToken,,,,) = booster.poolInfo(pid);
            address cvxToken = address(basePool);

            vm.startPrank(creditAccount);

            booster.deposit(pid, WAD);
            comparator.takeSnapshot("after_booster_deposit", creditAccount);

            uint256 remainingBalance = IERC20(crvToken).balanceOf(creditAccount);
            booster.deposit(pid, remainingBalance - WAD);
            comparator.takeSnapshot("after_booster_depositDiff", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            basePool.getReward(creditAccount);
            comparator.takeSnapshot("after_rewardPool_getReward", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            basePool.withdraw(WAD, true);
            comparator.takeSnapshot("after_rewardPool_withdraw", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            remainingBalance = IERC20(cvxToken).balanceOf(creditAccount);
            basePool.withdraw(remainingBalance - WAD, true);
            comparator.takeSnapshot("after_rewardPool_withdrawDiff", creditAccount);

            vm.stopPrank();
        }
    }

    function openCreditAccountWithUnderlying(address token, uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);

        tokenTestSuite.mint(token, creditAccount, amount);
    }

    function prepareComparator(address basePoolAdapter, address booster)
        internal
        returns (BalanceComparator comparator)
    {
        address[] memory tokensToTrack = new address[](8);

        tokensToTrack[0] = IConvexL2RewardPoolAdapter(basePoolAdapter).curveLPtoken();
        tokensToTrack[1] = IConvexL2RewardPoolAdapter(basePoolAdapter).targetContract();
        tokensToTrack[2] = IConvexL2RewardPoolAdapter(basePoolAdapter).reward0();
        tokensToTrack[3] = IConvexL2RewardPoolAdapter(basePoolAdapter).reward1();
        tokensToTrack[4] = IConvexL2RewardPoolAdapter(basePoolAdapter).reward2();
        tokensToTrack[5] = IConvexL2RewardPoolAdapter(basePoolAdapter).reward3();
        tokensToTrack[6] = IConvexL2RewardPoolAdapter(basePoolAdapter).reward4();
        tokensToTrack[7] = IConvexL2RewardPoolAdapter(basePoolAdapter).reward5();

        tokensToTrack = tokensToTrack.trim();

        Tokens[] memory _tokensToTrack = new Tokens[](tokensToTrack.length);

        for (uint256 j = 0; j < tokensToTrack.length; ++j) {
            _tokensToTrack[j] = tokenTestSuite.tokenIndexes(tokensToTrack[j]);
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    /// @dev [L-CVXL2ET-1]: Convex L2 adapters and original contracts work identically
    function test_live_CVXL2ET_01_Convex_L2_adapters_and_original_contracts_are_equivalent() public attachOrLiveTest {
        address[] memory adapters = creditConfigurator.allowedAdapters();

        for (uint256 i = 0; i < adapters.length; ++i) {
            if (IAdapter(adapters[i])._gearboxAdapterType() != AdapterType.CONVEX_L2_REWARD_POOL) continue;

            uint256 snapshot0 = vm.snapshot();

            address creditAccount =
                openCreditAccountWithUnderlying(IConvexL2RewardPoolAdapter(adapters[i]).curveLPtoken(), 3000 * WAD);

            address booster = IConvexRewardPool_L2(IAdapter(adapters[i]).targetContract()).convexBooster();

            tokenTestSuite.approve(IConvexL2RewardPoolAdapter(adapters[i]).curveLPtoken(), creditAccount, booster);

            uint256 snapshot1 = vm.snapshot();

            BalanceComparator comparator = prepareComparator(adapters[i], booster);

            compareBehavior(creditAccount, booster, IAdapter(adapters[i]).targetContract(), false, comparator);

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

            vm.revertTo(snapshot1);

            comparator = prepareComparator(adapters[i], booster);

            compareBehavior(creditAccount, creditManager.contractToAdapter(booster), adapters[i], true, comparator);

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);

            vm.revertTo(snapshot0);
        }
    }
}
