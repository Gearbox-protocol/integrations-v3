// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {IBaseRewardPool} from "../../../../integrations/convex/IBaseRewardPool.sol";
import {IRewards} from "../../../../integrations/convex/IRewards.sol";
import {IBooster} from "../../../../integrations/convex/IBooster.sol";
import {IConvexV1BaseRewardPoolAdapter} from "../../../../interfaces/convex/IConvexV1BaseRewardPoolAdapter.sol";
import {ConvexStakedPositionToken} from "../../../../helpers/convex/ConvexV1_StakedPositionToken.sol";
import {
    IPhantomToken,
    IPhantomTokenWithdrawer
} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";
import {PriceFeedParams} from "@gearbox-protocol/core-v3/contracts/interfaces/IPriceOracleV3.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {IPhantomTokenAdapter} from "../../../../interfaces/IPhantomTokenAdapter.sol";

import {
    ConvexV1_BaseRewardPoolCalls,
    ConvexV1_BaseRewardPoolMulticaller
} from "../../../multicall/convex/ConvexV1_BaseRewardPoolCalls.sol";
import {ConvexV1_BoosterCalls, ConvexV1_BoosterMulticaller} from "../../../multicall/convex/ConvexV1_BoosterCalls.sol";
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

/// @notice This also includes Aura pools
contract Live_ConvexEquivalenceTest is LiveTestHelper {
    using AddressList for address[];
    using ConvexV1_BaseRewardPoolCalls for ConvexV1_BaseRewardPoolMulticaller;
    using ConvexV1_BoosterCalls for ConvexV1_BoosterMulticaller;

    string[14] stages = [
        "after_booster_deposit_no_staking",
        "after_booster_depositDiff_no_staking",
        "after_basePool_stake",
        "after_basePool_stakeDiff",
        "after_basePool_getReward_with_extras",
        "after_basePool_withdraw",
        "after_basePool_withdrawDiff",
        "after_booster_withdraw",
        "after_booster_withdrawDiff",
        "after_booster_deposit_with_staking",
        "after_booster_depositDiff_with_staking",
        "after_basePool_withdrawAndUnwrap",
        "after_basePool_withdrawDiffAndUnwrap"
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
            uint256 pid = IBaseRewardPool((IConvexV1BaseRewardPoolAdapter(basePoolAddress).targetContract())).pid();
            ConvexV1_BoosterMulticaller booster = ConvexV1_BoosterMulticaller(boosterAddress);
            ConvexV1_BaseRewardPoolMulticaller basePool = ConvexV1_BaseRewardPoolMulticaller(basePoolAddress);

            vm.startPrank(USER);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(booster.deposit(pid, WAD, false)));
            comparator.takeSnapshot("after_booster_deposit_no_staking", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(booster.depositDiff(pid, WAD, false)));
            comparator.takeSnapshot("after_booster_depositDiff_no_staking", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(basePool.stake(WAD)));
            comparator.takeSnapshot("after_basePool_stake", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(basePool.stakeDiff(WAD)));
            comparator.takeSnapshot("after_basePool_stakeDiff", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(basePool.getReward()));
            comparator.takeSnapshot("after_basePool_getReward_with_extras", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(basePool.withdraw(WAD, true)));
            comparator.takeSnapshot("after_basePool_withdraw", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(basePool.withdrawDiff(WAD, true)));
            comparator.takeSnapshot("after_basePool_withdrawDiff", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(booster.withdraw(pid, WAD)));
            comparator.takeSnapshot("after_booster_withdraw", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(booster.withdrawDiff(pid, WAD)));
            comparator.takeSnapshot("after_booster_withdrawDiff", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(booster.deposit(pid, WAD, true)));
            comparator.takeSnapshot("after_booster_deposit_with_staking", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(booster.depositDiff(pid, WAD, true)));
            comparator.takeSnapshot("after_booster_depositDiff_with_staking", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(basePool.withdrawAndUnwrap(WAD, true)));
            comparator.takeSnapshot("after_basePool_withdrawAndUnwrap", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(basePool.withdrawDiffAndUnwrap(WAD, true)));
            comparator.takeSnapshot("after_basePool_withdrawDiffAndUnwrap", creditAccount);

            vm.stopPrank();
        } else {
            IBooster booster = IBooster(boosterAddress);
            IBaseRewardPool basePool = IBaseRewardPool(basePoolAddress);

            uint256 pid = basePool.pid();

            address crvToken = booster.poolInfo(pid).lptoken;
            address cvxToken = address(basePool.stakingToken());
            address stkcvxToken = address(basePool);

            vm.startPrank(creditAccount);

            booster.deposit(pid, WAD, false);
            comparator.takeSnapshot("after_booster_deposit_no_staking", creditAccount);

            uint256 remainingBalance = IERC20(crvToken).balanceOf(creditAccount);
            booster.deposit(pid, remainingBalance - WAD, false);
            comparator.takeSnapshot("after_booster_depositDiff_no_staking", creditAccount);

            basePool.stake(WAD);
            comparator.takeSnapshot("after_basePool_stake", creditAccount);

            remainingBalance = IERC20(cvxToken).balanceOf(creditAccount);
            basePool.stake(remainingBalance - WAD);
            comparator.takeSnapshot("after_basePool_stakeDiff", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            basePool.getReward();
            comparator.takeSnapshot("after_basePool_getReward_with_extras", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            basePool.withdraw(WAD, true);
            comparator.takeSnapshot("after_basePool_withdraw", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            remainingBalance = IERC20(stkcvxToken).balanceOf(creditAccount);
            basePool.withdraw(remainingBalance - WAD, true);
            comparator.takeSnapshot("after_basePool_withdrawDiff", creditAccount);

            booster.withdraw(pid, WAD);
            comparator.takeSnapshot("after_booster_withdraw", creditAccount);

            remainingBalance = IERC20(cvxToken).balanceOf(creditAccount);
            booster.withdraw(pid, remainingBalance - WAD);
            comparator.takeSnapshot("after_booster_withdrawDiff", creditAccount);

            booster.deposit(pid, WAD, true);
            comparator.takeSnapshot("after_booster_deposit_with_staking", creditAccount);

            remainingBalance = IERC20(crvToken).balanceOf(creditAccount);
            booster.deposit(pid, remainingBalance - WAD, true);
            comparator.takeSnapshot("after_booster_depositDiff_with_staking", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            basePool.withdrawAndUnwrap(WAD, true);
            comparator.takeSnapshot("after_basePool_withdrawAndUnwrap", creditAccount);

            vm.warp(block.timestamp + 24 * 60 * 60);

            remainingBalance = IERC20(stkcvxToken).balanceOf(creditAccount);
            basePool.withdrawAndUnwrap(remainingBalance - WAD, true);
            comparator.takeSnapshot("after_basePool_withdrawDiffAndUnwrap", creditAccount);

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
        address[] memory tokensToTrack = new address[](7);

        tokensToTrack[0] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter).curveLPtoken();
        tokensToTrack[1] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter).stakingToken();
        tokensToTrack[2] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter).stakedPhantomToken();
        tokensToTrack[3] = IBooster(booster).crv();
        tokensToTrack[4] = IBooster(booster).minter();
        tokensToTrack[5] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter).extraReward1();
        tokensToTrack[6] = IConvexV1BaseRewardPoolAdapter(basePoolAdapter).extraReward2();

        tokensToTrack = tokensToTrack.trim();

        uint256[] memory _tokensToTrack = new uint256[](tokensToTrack.length);

        for (uint256 j = 0; j < tokensToTrack.length; ++j) {
            _tokensToTrack[j] = tokenTestSuite.tokenIndexes(tokensToTrack[j]);
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    /// @dev [L-CVXET-1]: Convex / Aura adapters and original contracts work identically
    function test_live_CVXET_01_Convex_adapters_and_original_contracts_are_equivalent() public attachOrLiveTest {
        address[] memory adapters = creditConfigurator.allowedAdapters();

        for (uint256 i = 0; i < adapters.length; ++i) {
            if (IAdapter(adapters[i]).contractType() != "ADAPTER::CVX_V1_BASE_REWARD_POOL") continue;

            uint256 snapshot0 = vm.snapshot();

            address creditAccount =
                openCreditAccountWithUnderlying(IConvexV1BaseRewardPoolAdapter(adapters[i]).curveLPtoken(), 3000 * WAD);

            address booster = IBaseRewardPool(IAdapter(adapters[i]).targetContract()).operator();

            tokenTestSuite.approve(IConvexV1BaseRewardPoolAdapter(adapters[i]).curveLPtoken(), creditAccount, booster);

            tokenTestSuite.approve(
                IConvexV1BaseRewardPoolAdapter(adapters[i]).stakingToken(),
                creditAccount,
                IAdapter(adapters[i]).targetContract()
            );

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

    /// @dev [L-CVXET-2]: Withdrawals for Convex phantom tokens work correctly
    function test_live_CVXET_02_Convex_phantom_token_withdrawals_work_correctly() public attachOrLiveTest {
        uint256 collateralTokensCount = creditManager.collateralTokensCount();

        for (uint256 i = 0; i < collateralTokensCount; ++i) {
            uint256 snapshot = vm.snapshot();

            address token = creditManager.getTokenByMask(1 << i);

            try IPhantomToken(token).getPhantomTokenInfo() returns (address target, address) {
                address adapter = creditManager.contractToAdapter(target);
                if (IAdapter(adapter).contractType() != "ADAPTER::CVX_V1_BASE_REWARD_POOL") continue;
            } catch {
                continue;
            }

            address boosterAdapter = creditManager.contractToAdapter(ConvexStakedPositionToken(token).booster());
            address pool = ConvexStakedPositionToken(token).pool();

            uint256 pid = IBaseRewardPool(pool).pid();

            if (priceOracle.reservePriceFeeds(token) == address(0)) {
                PriceFeedParams memory pfParams = priceOracle.priceFeedParams(token);
                vm.prank(Ownable(address(acl)).owner());
                priceOracle.setReservePriceFeed(token, pfParams.priceFeed, pfParams.stalenessPeriod);
            }

            address curveToken = ConvexStakedPositionToken(token).curveToken();

            address creditAccount = openCreditAccountWithUnderlying(curveToken, 100 * WAD);

            vm.prank(USER);
            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(ConvexV1_BoosterMulticaller(boosterAdapter).deposit(pid, WAD, true))
            );

            address poolAdapter = creditManager.contractToAdapter(pool);

            vm.expectCall(poolAdapter, abi.encodeCall(IPhantomTokenWithdrawer.withdrawPhantomToken, (token, WAD)));
            vm.prank(USER);
            MultiCall memory call = MultiCall({
                target: address(creditFacade),
                callData: abi.encodeCall(ICreditFacadeV3Multicall.withdrawCollateral, (token, WAD, USER))
            });

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(call));

            address convexToken = ConvexStakedPositionToken(token).underlying();

            assertEq(IERC20(convexToken).balanceOf(USER), WAD);

            vm.revertTo(snapshot);
        }
    }
}
