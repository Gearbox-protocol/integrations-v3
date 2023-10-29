// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

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

        baseRewardPool = new BaseRewardPoolMock(42, address(booster), convexStakingToken, crv);
        baseRewardPool.setExtraReward(0, address(extraReward1));
        baseRewardPool.setExtraReward(1, address(extraReward2));

        adapter = new ConvexV1BaseRewardPoolAdapter(
            address(creditManager),
            address(baseRewardPool),
            stakedPhantomToken
        );
    }

    /// @notice U:[CVX1R-1]: Constructor works as expected
    function test_U_CVX1R_01_constructor_works_as_expected() public {
        _readsTokenMask(curveLPToken);
        _readsTokenMask(convexStakingToken);
        _readsTokenMask(stakedPhantomToken);
        _readsTokenMask(crv);
        _readsTokenMask(cvx);
        adapter = new ConvexV1BaseRewardPoolAdapter(
            address(creditManager),
            address(baseRewardPool),
            stakedPhantomToken
        );

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.addressProvider(), address(addressProvider), "Incorrect addressProvider");
        assertEq(adapter.targetContract(), address(baseRewardPool), "Incorrect targetContract");
        assertEq(adapter.curveLPtoken(), curveLPToken, "Incorrect curveLPtoken");
        assertEq(adapter.stakingToken(), convexStakingToken, "Incorrect stakingToken");
        assertEq(adapter.stakedPhantomToken(), stakedPhantomToken, "Incorrect stakedPhantomToken");
        assertEq(adapter.extraReward1(), address(0), "Incorrect extraReward1");
        assertEq(adapter.extraReward2(), address(0), "Incorrect extraReward2");
        assertEq(adapter.curveLPTokenMask(), 1, "Incorrect curveLPTokenMask");
        assertEq(adapter.stakingTokenMask(), 2, "Incorrect stakingTokenMask");
        assertEq(adapter.stakedTokenMask(), 4, "Incorrect stakedTokenMask");
        assertEq(adapter.rewardTokensMask(), 8 + 16, "Incorrect rewardTokensMask");
    }

    /// @notice U:[CVX1R-2]: Extra rewards are handled correctly
    function test_U_CVX1R_02_extra_rewards_are_handled_correctly() public {
        baseRewardPool.setNumExtraRewards(1);
        _readsTokenMask(tokens[5]);
        adapter = new ConvexV1BaseRewardPoolAdapter(
            address(creditManager),
            address(baseRewardPool),
            stakedPhantomToken
        );
        assertEq(adapter.extraReward1(), tokens[5], "Incorrect extraReward1");
        assertEq(adapter.extraReward2(), address(0), "Incorrect extraReward1");
        assertEq(adapter.rewardTokensMask(), 8 + 16 + 32, "Incorrect rewardTokensMask");

        baseRewardPool.setNumExtraRewards(2);
        _readsTokenMask(tokens[5]);
        _readsTokenMask(tokens[6]);
        adapter = new ConvexV1BaseRewardPoolAdapter(
            address(creditManager),
            address(baseRewardPool),
            stakedPhantomToken
        );
        assertEq(adapter.extraReward1(), tokens[5], "Incorrect extraReward1");
        assertEq(adapter.extraReward2(), tokens[6], "Incorrect extraReward1");
        assertEq(adapter.rewardTokensMask(), 8 + 16 + 32 + 64, "Incorrect rewardTokensMask");
    }

    /// @notice U:[CVX1R-3]: Wrapper functions revert on wrong caller
    function test_U_CVX1R_03_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.stake(0);

        _revertsOnNonFacadeCaller();
        adapter.stakeAll();

        _revertsOnNonFacadeCaller();
        adapter.getReward();

        _revertsOnNonFacadeCaller();
        adapter.withdraw(0, false);

        _revertsOnNonFacadeCaller();
        adapter.withdrawAll(false);

        _revertsOnNonFacadeCaller();
        adapter.withdrawAndUnwrap(0, false);

        _revertsOnNonFacadeCaller();
        adapter.withdrawAllAndUnwrap(false);
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

    /// @notice U:[CVX1R-5]: `stakeAll` works as expected
    function test_U_CVX1R_05_stakeAll_works_as_expected() public {
        _executesSwap({
            tokenIn: convexStakingToken,
            tokenOut: stakedPhantomToken,
            callData: abi.encodeCall(adapter.stakeAll, ()),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.stakeAll();
        assertEq(tokensToEnable, 4, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 2, "Incorrect tokensToDisable");
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

    /// @notice U:[CVX1R-8]: `withdrawAll` works as expected
    function test_U_CVX1R_08_withdrawAll_works_as_expected() public {
        for (uint256 i; i < 2; ++i) {
            bool claim = i == 1;
            _executesSwap({
                tokenIn: stakedPhantomToken,
                tokenOut: convexStakingToken,
                callData: abi.encodeCall(adapter.withdrawAll, (claim)),
                requiresApproval: false,
                validatesTokens: false
            });
            vm.prank(creditFacade);
            (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdrawAll(claim);
            assertEq(tokensToEnable, claim ? (2 + 8 + 16) : 2, "Incorrect tokensToEnable");
            assertEq(tokensToDisable, 4, "Incorrect tokensToDisable");
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

    /// @notice U:[CVX1R-10]: `withdrawAllAndUnwrap` works as expected
    function test_U_CVX1R_10_withdrawAllAndUnwrap_works_as_expected() public {
        for (uint256 i; i < 2; ++i) {
            bool claim = i == 1;
            _executesSwap({
                tokenIn: stakedPhantomToken,
                tokenOut: curveLPToken,
                callData: abi.encodeCall(adapter.withdrawAllAndUnwrap, (claim)),
                requiresApproval: false,
                validatesTokens: false
            });
            vm.prank(creditFacade);
            (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdrawAllAndUnwrap(claim);
            assertEq(tokensToEnable, claim ? (1 + 8 + 16) : 1, "Incorrect tokensToEnable");
            assertEq(tokensToDisable, 4, "Incorrect tokensToDisable");
        }
    }
}
