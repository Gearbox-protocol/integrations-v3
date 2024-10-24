// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {StakingRewardsAdapter} from "../../../../adapters/sky/StakingRewardsAdapter.sol";
import {IStakingRewards} from "../../../../integrations/sky/IStakingRewards.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Staking Rewards adapter unit test
/// @notice U:[SR]: Unit tests for Staking Rewards adapter
contract StakingRewardsAdapterUnitTest is AdapterUnitTestHelper {
    StakingRewardsAdapter adapter;

    address stakingRewards;
    address stakingToken;
    address rewardsToken;
    address stakedPhantomToken;

    function setUp() public {
        _setUp();

        stakingToken = tokens[0];
        rewardsToken = tokens[1];
        stakedPhantomToken = tokens[2];
        stakingRewards = tokens[3];

        vm.mockCall(stakingRewards, abi.encodeCall(IStakingRewards.stakingToken, ()), abi.encode(stakingToken));
        vm.mockCall(stakingRewards, abi.encodeCall(IStakingRewards.rewardsToken, ()), abi.encode(rewardsToken));

        adapter = new StakingRewardsAdapter(address(creditManager), stakingRewards, stakedPhantomToken);
    }

    /// @notice U:[SR-1]: Constructor works as expected
    function test_U_SR_01_constructor_works_as_expected() public {
        _readsTokenMask(stakingToken);
        _readsTokenMask(rewardsToken);
        _readsTokenMask(stakedPhantomToken);
        adapter = new StakingRewardsAdapter(address(creditManager), stakingRewards, stakedPhantomToken);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), stakingRewards, "Incorrect targetContract");
        assertEq(adapter.stakingToken(), stakingToken, "Incorrect stakingToken");
        assertEq(adapter.rewardsToken(), rewardsToken, "Incorrect rewardsToken");
        assertEq(adapter.stakedPhantomToken(), stakedPhantomToken, "Incorrect stakedPhantomToken");
    }

    /// @notice U:[SR-2]: Wrapper functions revert on wrong caller
    function test_U_SR_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.stake(0);

        _revertsOnNonFacadeCaller();
        adapter.stakeDiff(0);

        _revertsOnNonFacadeCaller();
        adapter.getReward();

        _revertsOnNonFacadeCaller();
        adapter.withdraw(0);

        _revertsOnNonFacadeCaller();
        adapter.withdrawDiff(0);

        _revertsOnNonFacadeCaller();
        adapter.withdrawPhantomToken(address(0), 0);
    }

    // ----- //
    // STAKE //
    // ----- //

    /// @notice U:[SR-3]: `stake` works as expected
    function test_U_SR_03_stake_works_as_expected() public {
        _executesSwap({
            tokenIn: stakingToken,
            callData: abi.encodeCall(IStakingRewards.stake, (1000)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.stake(1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[SR-4]: `stakeDiff` works as expected
    function test_U_SR_04_stakeDiff_works_as_expected() public diffTestCases {
        deal({token: stakingToken, to: creditAccount, give: diffMintedAmount});
        _readsActiveAccount();
        _executesSwap({
            tokenIn: stakingToken,
            callData: abi.encodeCall(IStakingRewards.stake, (diffInputAmount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.stakeDiff(diffLeftoverAmount);
        assertFalse(useSafePrices);
    }

    // ----- //
    // CLAIM //
    // ----- //

    /// @notice U:[SR-5]: `getReward` works as expected
    function test_U_SR_05_getReward_works_as_expected() public {
        _executesCall({tokensToApprove: new address[](0), callData: abi.encodeCall(IStakingRewards.getReward, ())});
        vm.prank(creditFacade);
        bool useSafePrices = adapter.getReward();
        assertFalse(useSafePrices);
    }

    // -------- //
    // WITHDRAW //
    // -------- //

    /// @notice U:[SR-6]: `withdraw` works as expected
    function test_U_SR_06_withdraw_works_as_expected() public {
        _executesSwap({
            tokenIn: stakedPhantomToken,
            callData: abi.encodeCall(IStakingRewards.withdraw, (1000)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdraw(1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[SR-7]: `withdrawDiff` works as expected
    function test_U_SR_07_withdrawDiff_works_as_expected() public diffTestCases {
        deal({token: stakedPhantomToken, to: creditAccount, give: diffMintedAmount});
        _readsActiveAccount();
        _executesSwap({
            tokenIn: stakedPhantomToken,
            callData: abi.encodeCall(IStakingRewards.withdraw, (diffInputAmount)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawDiff(diffLeftoverAmount);
        assertFalse(useSafePrices);
    }

    /// @notice U:[SR-8]: `withdrawPhantomToken` works as expected
    function test_U_SR_08_withdrawPhantomToken_works_as_expected() public {
        _executesSwap({
            tokenIn: stakedPhantomToken,
            callData: abi.encodeCall(IStakingRewards.withdraw, (1000)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawPhantomToken(address(0), 1000);
        assertFalse(useSafePrices);
    }
}
