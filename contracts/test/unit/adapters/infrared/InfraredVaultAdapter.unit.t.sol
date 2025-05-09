// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {InfraredVaultAdapter} from "../../../../adapters/infrared/InfraredVaultAdapter.sol";
import {IInfraredVault, UserReward} from "../../../../integrations/infrared/IInfraredVault.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title InfraredVault adapter unit test
/// @notice U:[IRV]: Unit tests for InfraredVault adapter
contract InfraredVaultAdapterUnitTest is AdapterUnitTestHelper {
    InfraredVaultAdapter adapter;

    address infraredVault;
    address stakingToken;
    address stakedPhantomToken;
    address[] rewardTokens;

    function setUp() public {
        _setUp();

        stakingToken = tokens[0];
        stakedPhantomToken = tokens[1];
        infraredVault = tokens[2];

        // Setup multiple reward tokens
        rewardTokens = new address[](3);
        rewardTokens[0] = tokens[3];
        rewardTokens[1] = tokens[4];
        rewardTokens[2] = tokens[5];

        vm.mockCall(infraredVault, abi.encodeCall(IInfraredVault.stakingToken, ()), abi.encode(stakingToken));
        vm.mockCall(infraredVault, abi.encodeCall(IInfraredVault.getAllRewardTokens, ()), abi.encode(rewardTokens));

        adapter = new InfraredVaultAdapter(address(creditManager), infraredVault, stakedPhantomToken);
    }

    /// @notice U:[IRV-1]: Constructor works as expected
    function test_U_IRV_01_constructor_works_as_expected() public {
        _readsTokenMask(stakingToken);
        _readsTokenMask(stakedPhantomToken);

        // Check that the adapter registers all reward tokens
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            _readsTokenMask(rewardTokens[i]);
        }

        adapter = new InfraredVaultAdapter(address(creditManager), infraredVault, stakedPhantomToken);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), infraredVault, "Incorrect targetContract");
        assertEq(adapter.stakingToken(), stakingToken, "Incorrect stakingToken");
        assertEq(adapter.stakedPhantomToken(), stakedPhantomToken, "Incorrect stakedPhantomToken");

        // Verify reward tokens were stored correctly
        address[] memory storedRewardTokens = adapter.rewardTokens();
        assertEq(storedRewardTokens.length, rewardTokens.length, "Incorrect number of reward tokens");
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            assertEq(storedRewardTokens[i], rewardTokens[i], "Incorrect reward token");
        }
    }

    /// @notice U:[IRV-2]: Wrapper functions revert on wrong caller
    function test_U_IRV_02_wrapper_functions_revert_on_wrong_caller() public {
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
        adapter.exit();

        _revertsOnNonFacadeCaller();
        adapter.withdrawPhantomToken(address(0), 0);
    }

    // ----- //
    // STAKE //
    // ----- //

    /// @notice U:[IRV-3]: `stake` works as expected
    function test_U_IRV_03_stake_works_as_expected() public {
        _executesSwap({
            tokenIn: stakingToken,
            callData: abi.encodeCall(IInfraredVault.stake, (1000)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.stake(1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[IRV-4]: `stakeDiff` works as expected
    function test_U_IRV_04_stakeDiff_works_as_expected() public diffTestCases {
        deal({token: stakingToken, to: creditAccount, give: diffMintedAmount});
        _readsActiveAccount();
        _executesSwap({
            tokenIn: stakingToken,
            callData: abi.encodeCall(IInfraredVault.stake, (diffInputAmount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.stakeDiff(diffLeftoverAmount);
        assertFalse(useSafePrices);
    }

    // ----- //
    // CLAIM //
    // ----- //

    /// @notice U:[IRV-5]: `getReward` works as expected
    function test_U_IRV_05_getReward_works_as_expected() public {
        _executesCall({tokensToApprove: new address[](0), callData: abi.encodeCall(IInfraredVault.getReward, ())});
        vm.prank(creditFacade);
        bool useSafePrices = adapter.getReward();
        assertFalse(useSafePrices);
    }

    // -------- //
    // WITHDRAW //
    // -------- //

    /// @notice U:[IRV-6]: `withdraw` works as expected
    function test_U_IRV_06_withdraw_works_as_expected() public {
        _executesSwap({
            tokenIn: stakedPhantomToken,
            callData: abi.encodeCall(IInfraredVault.withdraw, (1000)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdraw(1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[IRV-7]: `withdrawDiff` works as expected
    function test_U_IRV_07_withdrawDiff_works_as_expected() public diffTestCases {
        deal({token: stakedPhantomToken, to: creditAccount, give: diffMintedAmount});
        _readsActiveAccount();
        _executesSwap({
            tokenIn: stakedPhantomToken,
            callData: abi.encodeCall(IInfraredVault.withdraw, (diffInputAmount)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawDiff(diffLeftoverAmount);
        assertFalse(useSafePrices);
    }

    /// @notice U:[IRV-8]: `exit` works as expected
    function test_U_IRV_08_exit_works_as_expected() public {
        _executesCall({tokensToApprove: new address[](0), callData: abi.encodeCall(IInfraredVault.exit, ())});
        vm.prank(creditFacade);
        bool useSafePrices = adapter.exit();
        assertFalse(useSafePrices);
    }

    /// @notice U:[IRV-9]: `withdrawPhantomToken` works as expected
    function test_U_IRV_09_withdrawPhantomToken_works_as_expected() public {
        _executesSwap({
            tokenIn: stakedPhantomToken,
            callData: abi.encodeCall(IInfraredVault.withdraw, (1000)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawPhantomToken(address(0), 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[IRV-10]: `rewardTokens` works as expected
    function test_U_IRV_10_rewardTokens_works_as_expected() public view {
        address[] memory storedRewardTokens = adapter.rewardTokens();
        assertEq(storedRewardTokens.length, rewardTokens.length, "Incorrect number of reward tokens");
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            assertEq(storedRewardTokens[i], rewardTokens[i], "Incorrect reward token");
        }
    }

    /// @notice U:[IRV-11]: `serialize` works as expected
    function test_U_IRV_11_serialize_works_as_expected() public view {
        bytes memory serialized = adapter.serialize();
        (
            address serializedCreditManager,
            address serializedTargetContract,
            address serializedStakingToken,
            address serializedStakedToken,
            address[] memory serializedRewardTokens
        ) = abi.decode(serialized, (address, address, address, address, address[]));

        assertEq(serializedCreditManager, address(creditManager), "Incorrect serialized creditManager");
        assertEq(serializedTargetContract, infraredVault, "Incorrect serialized targetContract");
        assertEq(serializedStakingToken, stakingToken, "Incorrect serialized stakingToken");
        assertEq(serializedStakedToken, stakedPhantomToken, "Incorrect serialized stakedPhantomToken");

        assertEq(serializedRewardTokens.length, rewardTokens.length, "Incorrect serialized reward tokens length");
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            assertEq(serializedRewardTokens[i], rewardTokens[i], "Incorrect serialized reward token");
        }
    }
}
