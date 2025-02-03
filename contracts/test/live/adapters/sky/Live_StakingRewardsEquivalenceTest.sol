// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {IStakingRewards} from "../../../../integrations/sky/IStakingRewards.sol";
import {IStakingRewardsAdapter} from "../../../../interfaces/sky/IStakingRewardsAdapter.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";
import {PriceFeedParams} from "@gearbox-protocol/core-v3/contracts/interfaces/IPriceOracleV3.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {IPhantomTokenWithdrawer} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

import {StakingRewards_Calls, StakingRewards_Multicaller} from "../../../multicall/sky/StakingRewards_Calls.sol";
import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

import "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";

import {AddressList} from "@gearbox-protocol/core-v3/contracts/test/lib/AddressList.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES
import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_StakingRewardsEquivalenceTest is LiveTestHelper {
    using AddressList for address[];
    using StakingRewards_Calls for StakingRewards_Multicaller;

    string[5] stages = ["after_stake", "after_stakeDiff", "after_getReward", "after_withdraw", "after_withdrawDiff"];

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
        address stakingRewardsAddress,
        address stakedPhantomToken,
        bool isAdapter,
        BalanceComparator comparator
    ) internal {
        if (isAdapter) {
            StakingRewards_Multicaller stakingRewards = StakingRewards_Multicaller(stakingRewardsAddress);

            vm.startPrank(USER);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(stakingRewards.stake(WAD)));
            comparator.takeSnapshot("after_stake", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(stakingRewards.stakeDiff(WAD)));
            comparator.takeSnapshot("after_stakeDiff", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(stakingRewards.getReward()));
            comparator.takeSnapshot("after_getReward", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(stakingRewards.withdraw(WAD)));
            comparator.takeSnapshot("after_withdraw", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(stakingRewards.withdrawDiff(WAD)));
            comparator.takeSnapshot("after_withdrawDiff", creditAccount);

            vm.stopPrank();
        } else {
            IStakingRewards stakingRewards = IStakingRewards(stakingRewardsAddress);

            vm.startPrank(creditAccount);

            stakingRewards.stake(WAD);
            comparator.takeSnapshot("after_stake", creditAccount);

            uint256 remainingBalance = IERC20(stakingRewards.stakingToken()).balanceOf(creditAccount);
            stakingRewards.stake(remainingBalance - WAD);
            comparator.takeSnapshot("after_stakeDiff", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            stakingRewards.getReward();
            comparator.takeSnapshot("after_getReward", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            stakingRewards.withdraw(WAD);
            comparator.takeSnapshot("after_withdraw", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            remainingBalance = IERC20(stakedPhantomToken).balanceOf(creditAccount);
            stakingRewards.withdraw(remainingBalance - WAD);
            comparator.takeSnapshot("after_withdrawDiff", creditAccount);

            vm.stopPrank();
        }
    }

    function openCreditAccountWithUnderlying(address token, uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);

        tokenTestSuite.mint(token, creditAccount, amount);
    }

    function prepareComparator(address stakingRewardsAdapter) internal returns (BalanceComparator comparator) {
        address[] memory tokensToTrack = new address[](3);

        tokensToTrack[0] = IStakingRewardsAdapter(stakingRewardsAdapter).stakingToken();
        tokensToTrack[1] = IStakingRewardsAdapter(stakingRewardsAdapter).rewardsToken();
        tokensToTrack[2] = IStakingRewardsAdapter(stakingRewardsAdapter).stakedPhantomToken();

        tokensToTrack = tokensToTrack.trim();

        uint256[] memory _tokensToTrack = new uint256[](tokensToTrack.length);

        for (uint256 j = 0; j < tokensToTrack.length; ++j) {
            _tokensToTrack[j] = tokenTestSuite.tokenIndexes(tokensToTrack[j]);
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    /// @dev [L-STRET-1]: StakingRewards adapters and original contracts work identically
    function test_live_STRET_01_StakingRewards_adapters_and_original_contracts_are_equivalent()
        public
        attachOrLiveTest
    {
        address[] memory adapters = creditConfigurator.allowedAdapters();

        for (uint256 i = 0; i < adapters.length; ++i) {
            if (IAdapter(adapters[i]).contractType() != "ADAPTER::STAKING_REWARDS") continue;

            uint256 snapshot0 = vm.snapshot();

            address creditAccount =
                openCreditAccountWithUnderlying(IStakingRewardsAdapter(adapters[i]).stakingToken(), 3000 * WAD);

            tokenTestSuite.approve(
                IStakingRewardsAdapter(adapters[i]).stakingToken(),
                creditAccount,
                IAdapter(adapters[i]).targetContract()
            );

            uint256 snapshot1 = vm.snapshot();

            BalanceComparator comparator = prepareComparator(adapters[i]);

            compareBehavior(
                creditAccount,
                IAdapter(adapters[i]).targetContract(),
                IStakingRewardsAdapter(adapters[i]).stakedPhantomToken(),
                false,
                comparator
            );

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

            vm.revertTo(snapshot1);

            comparator = prepareComparator(adapters[i]);

            compareBehavior(
                creditAccount, adapters[i], IStakingRewardsAdapter(adapters[i]).stakedPhantomToken(), true, comparator
            );

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);

            vm.revertTo(snapshot0);
        }
    }

    /// @dev [L-STRET-2]: Withdrawals for StakingRewards phantom tokens work correctly
    function test_live_STRET_02_StakingRewards_phantom_token_withdrawals_work_correctly() public attachOrLiveTest {
        uint256 collateralTokensCount = creditManager.collateralTokensCount();

        for (uint256 i = 0; i < collateralTokensCount; ++i) {
            uint256 snapshot = vm.snapshot();

            address token = creditManager.getTokenByMask(1 << i);
            address adapter;

            try IPhantomToken(token).getPhantomTokenInfo() returns (address target, address) {
                adapter = creditManager.contractToAdapter(target);
                if (IAdapter(adapter).contractType() != "ADAPTER::STAKING_REWARDS") continue;
            } catch {
                continue;
            }

            if (priceOracle.reservePriceFeeds(token) == address(0)) {
                PriceFeedParams memory pfParams = priceOracle.priceFeedParams(token);
                vm.prank(Ownable(address(acl)).owner());
                priceOracle.setReservePriceFeed(token, pfParams.priceFeed, pfParams.stalenessPeriod);
            }

            address stakingToken = IStakingRewardsAdapter(adapter).stakingToken();

            address creditAccount = openCreditAccountWithUnderlying(stakingToken, 100 * WAD);

            vm.prank(USER);
            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(StakingRewards_Multicaller(adapter).stake(WAD))
            );

            vm.expectCall(adapter, abi.encodeCall(IPhantomTokenWithdrawer.withdrawPhantomToken, (token, WAD)));
            vm.prank(USER);
            MultiCall memory call = MultiCall({
                target: address(creditFacade),
                callData: abi.encodeCall(ICreditFacadeV3Multicall.withdrawCollateral, (token, WAD, USER))
            });

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(call));

            assertEq(IERC20(stakingToken).balanceOf(USER), WAD);

            vm.revertTo(snapshot);
        }
    }
}
