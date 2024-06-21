// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {ConvexV1BaseRewardPoolAdapter} from "../../../../adapters/convex/ConvexV1_BaseRewardPool.sol";
import {BaseRewardPoolMock} from "../../../mocks/integrations/convex/BaseRewardPoolMock.sol";
import {BoosterMock} from "../../../mocks/integrations/convex/BoosterMock.sol";
import {ExtraRewardWrapperMock} from "../../../mocks/integrations/convex/ExtraRewardWrapperMock.sol";
import {RewardsMock} from "../../../mocks/integrations/convex/RewardsMock.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Convex v1 base reward pool adapter unit test
/// @notice U:[CVX1R]: Unit tests for Convex v1 base reward pool adapter
contract ConvexV1BaseRewardPoolAdapterUnitTest is AdapterUnitTestHelper {
    ConvexV1BaseRewardPoolAdapter adapter;

    BaseRewardPoolMock baseRewardPool;
    BoosterMock booster;

    RewardsMock extraReward1;
    RewardsMock extraReward2;
    RewardsMock extraReward3;
    RewardsMock extraReward4;

    address curveLPToken;
    address convexStakingToken;
    address stakedPhantomToken;
    address crv;
    address cvx;

    function setUp() public {
        _setUp();

        curveLPToken = tokens[0];
        convexStakingToken = tokens[1];
        stakedPhantomToken = tokens[2];
        crv = tokens[3];
        cvx = tokens[4];

        booster = new BoosterMock(cvx);
        booster.setPoolInfo(42, curveLPToken, convexStakingToken);

        extraReward1 = new RewardsMock(tokens[5]);
        extraReward2 = new RewardsMock(address(new ExtraRewardWrapperMock(tokens[6])));
        extraReward3 = new RewardsMock(tokens[7]);
        extraReward4 = new RewardsMock(tokens[8]);

        baseRewardPool = new BaseRewardPoolMock(42, address(booster), convexStakingToken, crv);
        baseRewardPool.setExtraReward(0, address(extraReward1));
        baseRewardPool.setExtraReward(1, address(extraReward2));
        baseRewardPool.setExtraReward(2, address(extraReward3));
        baseRewardPool.setExtraReward(3, address(extraReward4));

        adapter = new ConvexV1BaseRewardPoolAdapter(address(creditManager), address(baseRewardPool), stakedPhantomToken);
    }

    /// @notice U:[CVX1R-1]: Constructor works as expected
    function test_U_CVX1R_01_constructor_works_as_expected() public {
        _readsTokenMask(curveLPToken);
        _readsTokenMask(convexStakingToken);
        _readsTokenMask(stakedPhantomToken);
        _readsTokenMask(crv);
        _readsTokenMask(cvx);
        adapter = new ConvexV1BaseRewardPoolAdapter(address(creditManager), address(baseRewardPool), stakedPhantomToken);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), address(baseRewardPool), "Incorrect targetContract");
        assertEq(adapter.curveLPtoken(), curveLPToken, "Incorrect curveLPtoken");
        assertEq(adapter.stakingToken(), convexStakingToken, "Incorrect stakingToken");
        assertEq(adapter.stakedPhantomToken(), stakedPhantomToken, "Incorrect stakedPhantomToken");
        assertEq(adapter.extraReward1(), address(0), "Incorrect extraReward1");
        assertEq(adapter.extraReward2(), address(0), "Incorrect extraReward2");
        assertEq(adapter.extraReward3(), address(0), "Incorrect extraReward3");
        assertEq(adapter.extraReward4(), address(0), "Incorrect extraReward4");
        assertEq(adapter.curveLPTokenMask(), 1, "Incorrect curveLPTokenMask");
        assertEq(adapter.stakingTokenMask(), 2, "Incorrect stakingTokenMask");
        assertEq(adapter.stakedTokenMask(), 4, "Incorrect stakedTokenMask");
        assertEq(adapter.rewardTokensMask(), 8 + 16, "Incorrect rewardTokensMask");
    }

    /// @notice U:[CVX1R-2]: Extra rewards are handled correctly
    function test_U_CVX1R_02_extra_rewards_are_handled_correctly() public {
        baseRewardPool.setNumExtraRewards(1);
        _readsTokenMask(tokens[5]);
        adapter = new ConvexV1BaseRewardPoolAdapter(address(creditManager), address(baseRewardPool), stakedPhantomToken);
        assertEq(adapter.extraReward1(), tokens[5], "Incorrect extraReward1");
        assertEq(adapter.extraReward2(), address(0), "Incorrect extraReward1");
        assertEq(adapter.rewardTokensMask(), 8 + 16 + 32, "Incorrect rewardTokensMask");

        baseRewardPool.setNumExtraRewards(2);
        _readsTokenMask(tokens[5]);
        _readsTokenMask(tokens[6]);
        adapter = new ConvexV1BaseRewardPoolAdapter(address(creditManager), address(baseRewardPool), stakedPhantomToken);
        assertEq(adapter.extraReward1(), tokens[5], "Incorrect extraReward1");
        assertEq(adapter.extraReward2(), tokens[6], "Incorrect extraReward2");
        assertEq(adapter.rewardTokensMask(), 8 + 16 + 32 + 64, "Incorrect rewardTokensMask");

        baseRewardPool.setNumExtraRewards(3);
        _readsTokenMask(tokens[5]);
        _readsTokenMask(tokens[6]);
        _readsTokenMask(tokens[7]);
        adapter = new ConvexV1BaseRewardPoolAdapter(address(creditManager), address(baseRewardPool), stakedPhantomToken);
        assertEq(adapter.extraReward1(), tokens[5], "Incorrect extraReward1");
        assertEq(adapter.extraReward2(), tokens[6], "Incorrect extraReward2");
        assertEq(adapter.extraReward3(), tokens[7], "Incorrect extraReward3");
        assertEq(adapter.rewardTokensMask(), 8 + 16 + 32 + 64 + 128, "Incorrect rewardTokensMask");

        baseRewardPool.setNumExtraRewards(4);
        _readsTokenMask(tokens[5]);
        _readsTokenMask(tokens[6]);
        _readsTokenMask(tokens[7]);
        _readsTokenMask(tokens[8]);
        adapter = new ConvexV1BaseRewardPoolAdapter(address(creditManager), address(baseRewardPool), stakedPhantomToken);
        assertEq(adapter.extraReward1(), tokens[5], "Incorrect extraReward1");
        assertEq(adapter.extraReward2(), tokens[6], "Incorrect extraReward2");
        assertEq(adapter.extraReward3(), tokens[7], "Incorrect extraReward3");
        assertEq(adapter.extraReward4(), tokens[8], "Incorrect extraReward4");
        assertEq(adapter.rewardTokensMask(), 8 + 16 + 32 + 64 + 128 + 256, "Incorrect rewardTokensMask");
    }

    /// @notice U:[CVX1R-3]: Wrapper functions revert on wrong caller
    function test_U_CVX1R_03_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.stake(0);

        _revertsOnNonFacadeCaller();
        adapter.stakeDiff(0);

        _revertsOnNonFacadeCaller();
        adapter.getReward();

        _revertsOnNonFacadeCaller();
        adapter.withdraw(0, false);

        _revertsOnNonFacadeCaller();
        adapter.withdrawDiff(0, false);

        _revertsOnNonFacadeCaller();
        adapter.withdrawAndUnwrap(0, false);

        _revertsOnNonFacadeCaller();
        adapter.withdrawDiffAndUnwrap(0, false);
    }

    // ----- //
    // STAKE //
    // ----- //

    /// @notice U:[CVX1R-4]: `stake` works as expected
    function test_U_CVX1R_04_stake_works_as_expected() public {
        _executesSwap({
            tokenIn: convexStakingToken,
            tokenOut: stakedPhantomToken,
            callData: abi.encodeCall(adapter.stake, (1000)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.stake(1000);
        assertEq(tokensToEnable, 4, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CVX1R-5]: `stakeDiff` works as expected
    function test_U_CVX1R_05_stakeDiff_works_as_expected() public diffTestCases {
        deal({token: convexStakingToken, to: creditAccount, give: diffMintedAmount});
        _readsActiveAccount();
        _executesSwap({
            tokenIn: convexStakingToken,
            tokenOut: stakedPhantomToken,
            callData: abi.encodeCall(adapter.stake, (diffInputAmount)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.stakeDiff(diffLeftoverAmount);
        assertEq(tokensToEnable, 4, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? 2 : 0, "Incorrect tokensToDisable");
    }

    // ----- //
    // CLAIM //
    // ----- //

    /// @notice U:[CVX1R-6]: `getReward` works as expected
    function test_U_CVX1R_06_getReward_works_as_expected() public {
        _executesCall({
            tokensToApprove: new address[](0),
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(adapter.getReward, ())
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.getReward();
        assertEq(tokensToEnable, 8 + 16, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    // -------- //
    // WITHDRAW //
    // -------- //

    /// @notice U:[CVX1R-7]: `withdraw` works as expected
    function test_U_CVX1R_07_withdraw_works_as_expected() public {
        for (uint256 i; i < 2; ++i) {
            bool claim = i == 1;
            _executesSwap({
                tokenIn: stakedPhantomToken,
                tokenOut: convexStakingToken,
                callData: abi.encodeCall(adapter.withdraw, (1000, claim)),
                requiresApproval: false,
                validatesTokens: false
            });
            vm.prank(creditFacade);
            (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdraw(1000, claim);
            assertEq(tokensToEnable, claim ? (2 + 8 + 16) : 2, "Incorrect tokensToEnable");
            assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
        }
    }

    /// @notice U:[CVX1R-8]: `withdrawDiff` works as expected
    function test_U_CVX1R_08_withdrawDiff_works_as_expected() public diffTestCases {
        deal({token: stakedPhantomToken, to: creditAccount, give: diffMintedAmount});
        for (uint256 i; i < 2; ++i) {
            bool claim = i == 1;
            _readsActiveAccount();
            _executesSwap({
                tokenIn: stakedPhantomToken,
                tokenOut: convexStakingToken,
                callData: abi.encodeCall(adapter.withdraw, (diffInputAmount, claim)),
                requiresApproval: false,
                validatesTokens: false
            });
            vm.prank(creditFacade);
            (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdrawDiff(diffLeftoverAmount, claim);
            assertEq(tokensToEnable, claim ? (2 + 8 + 16) : 2, "Incorrect tokensToEnable");
            assertEq(tokensToDisable, diffDisableTokenIn ? 4 : 0, "Incorrect tokensToDisable");
        }
    }

    // ------ //
    // UNWRAP //
    // ------ //

    /// @notice U:[CVX1R-9]: `withdrawAndUnwrap` works as expected
    function test_U_CVX1R_09_withdrawAndUnwrap_works_as_expected() public {
        for (uint256 i; i < 2; ++i) {
            bool claim = i == 1;
            _executesSwap({
                tokenIn: stakedPhantomToken,
                tokenOut: curveLPToken,
                callData: abi.encodeCall(adapter.withdrawAndUnwrap, (1000, claim)),
                requiresApproval: false,
                validatesTokens: false
            });
            vm.prank(creditFacade);
            (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdrawAndUnwrap(1000, claim);
            assertEq(tokensToEnable, claim ? (1 + 8 + 16) : 1, "Incorrect tokensToEnable");
            assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
        }
    }

    /// @notice U:[CVX1R-10]: `withdrawDiffAndUnwrap` works as expected
    function test_U_CVX1R_10_withdrawDiffAndUnwrap_works_as_expected() public diffTestCases {
        deal({token: stakedPhantomToken, to: creditAccount, give: diffMintedAmount});
        for (uint256 i; i < 2; ++i) {
            bool claim = i == 1;
            _readsActiveAccount();
            _executesSwap({
                tokenIn: stakedPhantomToken,
                tokenOut: curveLPToken,
                callData: abi.encodeCall(adapter.withdrawAndUnwrap, (diffInputAmount, claim)),
                requiresApproval: false,
                validatesTokens: false
            });
            vm.prank(creditFacade);
            (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdrawDiffAndUnwrap(diffLeftoverAmount, claim);
            assertEq(tokensToEnable, claim ? (1 + 8 + 16) : 1, "Incorrect tokensToEnable");
            assertEq(tokensToDisable, diffDisableTokenIn ? 4 : 0, "Incorrect tokensToDisable");
        }
    }
}
