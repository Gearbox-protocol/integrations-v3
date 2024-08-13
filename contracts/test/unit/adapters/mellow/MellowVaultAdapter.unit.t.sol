// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.17;

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
        assertEq(adapter.addressProvider(), address(addressProvider), "Incorrect addressProvider");
        assertEq(adapter.targetContract(), vault, "Incorrect targetContract");
        assertEq(adapter.vaultTokenMask(), 8, "Incorrect vault token mask");
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

        amounts[1] = 0;

        address[] memory tokensToApprove = new address[](1);
        tokensToApprove[0] = tokens[0];

        _readsActiveAccount();
        _executesCall({
            tokensToApprove: tokensToApprove,
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(IMellowVault.deposit, (creditAccount, amounts, 0, 789))
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.deposit(creditAccount, amounts, 0, 789);

        assertEq(tokensToEnable, 8, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[MEL-4]: `depositOneAsset` works as expected
    function test_U_MEL_04_depositOneAsset_works_as_expected() public {
        vm.expectRevert(abi.encodeWithSelector(UnderlyingNotAllowedException.selector, tokens[1]));
        vm.prank(creditFacade);
        adapter.depositOneAsset(tokens[1], 100, 0, 789);

        uint256[] memory amounts = new uint256[](3);

        amounts[0] = 100;

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[3],
            callData: abi.encodeCall(IMellowVault.deposit, (creditAccount, amounts, 0, 789)),
            requiresApproval: true,
            validatesTokens: false
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.depositOneAsset(tokens[0], 100, 0, 789);

        assertEq(tokensToEnable, 8, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[MEL-5]: `depositOneAssetDiff` works as expected
    function test_U_MEL_05_depositOneAssetDiff_works_as_expected() public diffTestCases {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        vm.expectRevert(abi.encodeWithSelector(UnderlyingNotAllowedException.selector, tokens[1]));
        vm.prank(creditFacade);
        adapter.depositOneAsset(tokens[1], diffInputAmount, diffInputAmount / 2, 789);

        uint256[] memory amounts = new uint256[](3);

        amounts[0] = diffInputAmount;

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[3],
            callData: abi.encodeCall(IMellowVault.deposit, (creditAccount, amounts, diffInputAmount / 2, 789)),
            requiresApproval: true,
            validatesTokens: false
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.depositOneAssetDiff(tokens[0], diffLeftoverAmount, 0.5e27, 789);

        assertEq(tokensToEnable, 8, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? 1 : 0, "Incorrect tokensToDisable");
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

        assertFalse(adapter.isUnderlyingAllowed(tokens[0]), "First token is incorrectly allowed");
        assertTrue(adapter.isUnderlyingAllowed(tokens[1]), "Second token is incorrectly not allowed");
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Sets statuses for `len` consecutive pairs of `tokens` based on `allowedPairsMask`
    function _setUnderlyingsStatus(uint256 len) internal {
        MellowUnderlyingStatus[] memory underlyings = new MellowUnderlyingStatus[](len);
        for (uint256 i; i < len; ++i) {
            underlyings[i] = MellowUnderlyingStatus(tokens[i], true);
        }
        vm.prank(configurator);
        adapter.setUnderlyingStatusBatch(underlyings);
    }
}
