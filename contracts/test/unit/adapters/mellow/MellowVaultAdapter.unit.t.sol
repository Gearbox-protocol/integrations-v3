// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMellowVault} from "../../../../integrations/mellow/IMellowVault.sol";
import {
    IMellowVaultAdapterEvents,
    IMellowVaultAdapterExceptions,
    MellowUnderlyingStatus
} from "../../../../interfaces/mellow/IMellowVaultAdapter.sol";
import {MellowVaultAdapter} from "../../../../adapters/mellow/MellowVaultAdapter.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Mellow Vault adapter unit test
/// @notice U:[MEL]: Unit tests for Mellow Vault adapter
contract MellowVaultAdapterUnitTest is
    AdapterUnitTestHelper,
    IMellowVaultAdapterEvents,
    IMellowVaultAdapterExceptions
{
    MellowVaultAdapter adapter;

    address vault;

    function setUp() public {
        _setUp();

        vault = tokens[3];
        adapter = new MellowVaultAdapter(address(creditManager), vault);

        address[] memory underlyings = new address[](3);
        underlyings[0] = tokens[0];
        underlyings[1] = tokens[1];
        underlyings[2] = tokens[2];

        vm.mockCall(vault, abi.encodeCall(IMellowVault.underlyingTokens, ()), abi.encode(underlyings));

        _setUnderlyingsStatus(1);
    }

    /// @notice U:[MEL-1]: Constructor works as expected
    function test_U_MEL_01_constructor_works_as_expected() public {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), vault, "Incorrect targetContract");
    }

    /// @notice U:[MEL-2]: Wrapper functions revert on wrong caller
    function test_U_MEL_02_wrapper_functions_revert_on_wrong_caller() public {
        uint256[] memory amounts;

        _revertsOnNonFacadeCaller();
        adapter.deposit(address(0), amounts, 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.depositOneAsset(address(0), 0, 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.depositOneAssetDiff(address(0), 0, 0, 0);
    }

    /// @notice U:[MEL-3]: `deposit` works as expected
    function test_U_MEL_03_deposit_works_as_expected() public {
        uint256[] memory amounts = new uint256[](3);

        amounts[0] = 100;
        amounts[1] = 200;

        vm.expectRevert(abi.encodeWithSelector(UnderlyingNotAllowedException.selector, tokens[1]));
        vm.prank(creditFacade);
        adapter.deposit(address(0), amounts, 0, 789);

        uint256[] memory incorrectAmounts = new uint256[](2);
        vm.expectRevert(IncorrectArrayLengthException.selector);
        vm.prank(creditFacade);
        adapter.deposit(address(0), incorrectAmounts, 0, 789);

        _setUnderlyingsStatus(3);

        address[] memory tokensToApprove = new address[](1);
        tokensToApprove[0] = tokens[0];

        _readsActiveAccount();
        _executesCall({
            tokensToApprove: tokensToApprove,
            callData: abi.encodeCall(IMellowVault.deposit, (creditAccount, amounts, 0, 789))
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.deposit(creditAccount, amounts, 0, 789);

        assertTrue(useSafePrices, "Should use safe prices");
    }

    /// @notice U:[MEL-4]: `depositOneAsset` works as expected
    function test_U_MEL_04_depositOneAsset_works_as_expected() public {
        vm.expectRevert(abi.encodeWithSelector(UnderlyingNotAllowedException.selector, tokens[1]));
        vm.prank(creditFacade);
        adapter.depositOneAsset(tokens[1], 100, 0, 789);

        address nonExistentToken = makeAddr("WRONG_TOKEN");

        creditManager.setMask(nonExistentToken, 4096);

        _allowUnderlying(nonExistentToken);
        vm.expectRevert(abi.encodeWithSelector(UnderlyingNotFoundException.selector, nonExistentToken));
        vm.prank(creditFacade);
        adapter.depositOneAsset(nonExistentToken, 100, 0, 789);

        uint256[] memory amounts = new uint256[](3);

        amounts[0] = 100;

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            callData: abi.encodeCall(IMellowVault.deposit, (creditAccount, amounts, 0, 789)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositOneAsset(tokens[0], 100, 0, 789);

        assertTrue(useSafePrices, "Should use safe prices");
    }

    /// @notice U:[MEL-5]: `depositOneAssetDiff` works as expected
    function test_U_MEL_05_depositOneAssetDiff_works_as_expected() public diffTestCases {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        vm.expectRevert(abi.encodeWithSelector(UnderlyingNotAllowedException.selector, tokens[1]));
        vm.prank(creditFacade);
        adapter.depositOneAssetDiff(tokens[1], diffLeftoverAmount, 0.5e27, 789);

        address nonExistentToken = makeAddr("WRONG_TOKEN");

        creditManager.setMask(nonExistentToken, 4096);

        _allowUnderlying(nonExistentToken);
        vm.mockCall(nonExistentToken, abi.encodeCall(IERC20.balanceOf, (creditAccount)), abi.encode(diffMintedAmount));
        vm.expectRevert(abi.encodeWithSelector(UnderlyingNotFoundException.selector, nonExistentToken));
        vm.prank(creditFacade);
        adapter.depositOneAssetDiff(nonExistentToken, diffLeftoverAmount, 0.5e27, 789);

        uint256[] memory amounts = new uint256[](3);

        amounts[0] = diffInputAmount;

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            callData: abi.encodeCall(IMellowVault.deposit, (creditAccount, amounts, diffInputAmount / 2, 789)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositOneAssetDiff(tokens[0], diffLeftoverAmount, 0.5e27, 789);

        assertTrue(useSafePrices, "Should use safe prices");
    }

    /// @notice U:[MEL-6]: `setUnderlyingStatusBatch` works as expected
    function test_U_MEL_06_setUnderlyingStatusBatch_works_as_expected() public {
        MellowUnderlyingStatus[] memory underlyings;

        _revertsOnNonConfiguratorCaller();
        adapter.setUnderlyingStatusBatch(underlyings);

        underlyings = new MellowUnderlyingStatus[](2);
        underlyings[0] = MellowUnderlyingStatus(tokens[0], false);
        underlyings[1] = MellowUnderlyingStatus(tokens[1], true);

        vm.expectEmit(true, false, false, true);
        emit SetUnderlyingStatus(tokens[0], false);

        vm.expectEmit(true, false, false, true);
        emit SetUnderlyingStatus(tokens[1], true);

        vm.prank(configurator);
        adapter.setUnderlyingStatusBatch(underlyings);

        address[] memory allowedUnderlyings = adapter.allowedUnderlyings();
        assertEq(allowedUnderlyings.length, 1, "Incorrect number of allowed underlyings");
        assertEq(allowedUnderlyings[0], tokens[1], "Incorrect allowed underlying");
    }

    // ------- //
    // HELPERS //
    // ------- //

    function _setUnderlyingsStatus(uint256 len) internal {
        MellowUnderlyingStatus[] memory underlyings = new MellowUnderlyingStatus[](len);
        for (uint256 i; i < len; ++i) {
            underlyings[i] = MellowUnderlyingStatus(tokens[i], true);
        }
        vm.prank(configurator);
        adapter.setUnderlyingStatusBatch(underlyings);
    }

    function _allowUnderlying(address token) internal {
        MellowUnderlyingStatus[] memory underlyings = new MellowUnderlyingStatus[](1);
        underlyings[0] = MellowUnderlyingStatus(token, true);
        vm.prank(configurator);
        adapter.setUnderlyingStatusBatch(underlyings);
    }
}
