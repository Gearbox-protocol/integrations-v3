// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MellowWrapperAdapter} from "../../../../adapters/mellow/MellowWrapperAdapter.sol";
import {
    IMellowWrapperAdapter,
    MellowVaultStatus,
    IMellowWrapperAdapterEvents,
    IMellowWrapperAdapterExceptions
} from "../../../../interfaces/mellow/IMellowWrapperAdapter.sol";
import {IMellowWrapper} from "../../../../integrations/mellow/IMellowWrapper.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

contract MellowWrapperAdapterUnitTest is
    AdapterUnitTestHelper,
    IMellowWrapperAdapterEvents,
    IMellowWrapperAdapterExceptions
{
    MellowWrapperAdapter adapter;
    address mellowWrapper;
    address weth;
    address referral;
    address vault;

    function setUp() public {
        _setUp();
        mellowWrapper = tokens[0];
        weth = tokens[1];
        referral = tokens[2];
        vault = tokens[3];
        vm.mockCall(mellowWrapper, abi.encodeCall(IMellowWrapper.WETH, ()), abi.encode(weth));
        adapter = new MellowWrapperAdapter(address(creditManager), mellowWrapper, referral);
    }

    /// @notice U:[MWA-1]: Constructor works as expected
    function test_U_MWA_01_constructor_works_as_expected() public view {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), mellowWrapper, "Incorrect targetContract");
        assertEq(adapter.referral(), referral, "Incorrect referral");
        assertEq(adapter.weth(), weth, "Incorrect weth");
    }

    /// @notice U:[MWA-2]: Wrapper functions revert on wrong caller
    function test_U_MWA_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.deposit(address(0), 1000, vault, address(0), address(0));
        _revertsOnNonFacadeCaller();
        adapter.depositDiff(1000, vault);
    }

    /// @notice U:[MWA-3]: Deposit reverts if vault is not allowed
    function test_U_MWA_03_deposit_reverts_if_vault_not_allowed() public {
        vm.prank(creditFacade);
        vm.expectRevert(abi.encodeWithSelector(VaultNotAllowedException.selector, vault));
        adapter.deposit(address(0), 1000, vault, address(0), address(0));
    }

    /// @notice U:[MWA-4]: Deposit executes if vault is allowed
    function test_U_MWA_04_deposit_executes_if_vault_allowed() public {
        _addAllowedVault(vault);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: weth,
            callData: abi.encodeCall(IMellowWrapper.deposit, (weth, 1000, vault, creditAccount, referral)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.deposit(address(0), 1000, vault, address(0), address(0));
        assertFalse(useSafePrices);
    }

    /// @notice U:[MWA-5]: DepositDiff reverts if vault is not allowed
    function test_U_MWA_05_depositDiff_reverts_if_vault_not_allowed() public {
        vm.prank(creditFacade);
        vm.expectRevert(abi.encodeWithSelector(VaultNotAllowedException.selector, vault));
        adapter.depositDiff(1000, vault);
    }

    /// @notice U:[MWA-6]: DepositDiff returns false if balance is too low
    function test_U_MWA_06_depositDiff_returns_false_if_balance_too_low() public {
        _addAllowedVault(vault);
        vm.mockCall(weth, abi.encodeCall(IERC20.balanceOf, (creditAccount)), abi.encode(500));
        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositDiff(1000, vault);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MWA-7]: DepositDiff executes if balance is sufficient
    function test_U_MWA_07_depositDiff_executes_if_balance_sufficient() public {
        _addAllowedVault(vault);
        vm.mockCall(weth, abi.encodeCall(IERC20.balanceOf, (creditAccount)), abi.encode(2000));
        _readsActiveAccount();
        _executesSwap({
            tokenIn: weth,
            callData: abi.encodeCall(IMellowWrapper.deposit, (weth, 1000, vault, creditAccount, referral)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositDiff(1000, vault);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MWA-8]: allowedVaults returns correct list
    function test_U_MWA_08_allowedVaults_returns_correct_list() public {
        assertEq(adapter.allowedVaults().length, 0, "Should be empty initially");
        _addAllowedVault(vault);
        address[] memory allowed = adapter.allowedVaults();
        assertEq(allowed.length, 1, "Should have one allowed vault");
        assertEq(allowed[0], vault, "Incorrect allowed vault");
    }

    /// @notice U:[MWA-9]: setVaultStatusBatch works as expected
    function test_U_MWA_09_setVaultStatusBatch_works_as_expected() public {
        MellowVaultStatus[] memory vaults = new MellowVaultStatus[](2);
        vaults[0] = MellowVaultStatus(vault, true);
        vaults[1] = MellowVaultStatus(tokens[4], true);
        _revertsOnNonConfiguratorCaller();
        adapter.setVaultStatusBatch(vaults);
        vm.expectEmit(true, false, false, true);
        emit SetVaultStatus(vault, true);
        vm.expectEmit(true, false, false, true);
        emit SetVaultStatus(tokens[4], true);
        vm.prank(configurator);
        adapter.setVaultStatusBatch(vaults);
        address[] memory allowed = adapter.allowedVaults();
        assertEq(allowed.length, 2, "Should have two allowed vaults");
        assertEq(allowed[0], vault, "First allowed vault incorrect");
        assertEq(allowed[1], tokens[4], "Second allowed vault incorrect");
        // Now remove one
        vaults[0] = MellowVaultStatus(vault, false);
        vm.expectEmit(true, false, false, true);
        emit SetVaultStatus(vault, false);
        vm.prank(configurator);
        adapter.setVaultStatusBatch(vaults);
        allowed = adapter.allowedVaults();
        assertEq(allowed.length, 1, "Should have one allowed vault after removal");
        assertEq(allowed[0], tokens[4], "Remaining allowed vault incorrect");
    }

    // ------- //
    // HELPERS //
    // ------- //
    function _addAllowedVault(address _vault) internal {
        MellowVaultStatus[] memory vaults = new MellowVaultStatus[](1);
        vaults[0] = MellowVaultStatus(_vault, true);
        vm.prank(configurator);
        adapter.setVaultStatusBatch(vaults);
    }
}
