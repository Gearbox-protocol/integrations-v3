// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Mellow4626VaultAdapter} from "../../../../adapters/mellow/Mellow4626VaultAdapter.sol";
import {IMellowMultiVault} from "../../../../integrations/mellow/IMellowMultiVault.sol";
import {IMellow4626VaultAdapter} from "../../../../interfaces/mellow/IMellow4626VaultAdapter.sol";
import {MellowWithdrawalPhantomToken} from "../../../../helpers/mellow/MellowWithdrawalPhantomToken.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Mellow4626Vault adapter unit test
/// @notice U:[M4626]: Unit tests for Mellow4626Vault adapter
contract Mellow4626VaultAdapterUnitTest is AdapterUnitTestHelper {
    Mellow4626VaultAdapter adapter;

    address vault;
    address asset;
    address stakedPhantomToken;

    function setUp() public {
        _setUp();

        asset = tokens[0];
        vault = tokens[1];
        stakedPhantomToken = tokens[2];

        vm.mockCall(vault, abi.encodeCall(IERC4626.asset, ()), abi.encode(asset));
        vm.mockCall(stakedPhantomToken, abi.encodeWithSignature("multiVault()"), abi.encode(vault));

        adapter = new Mellow4626VaultAdapter(address(creditManager), vault, stakedPhantomToken);
    }

    /// @notice U:[M4626-1]: Constructor works as expected
    function test_U_M4626_01_constructor_works_as_expected() public {
        _readsTokenMask(asset);
        _readsTokenMask(vault);
        _readsTokenMask(stakedPhantomToken);

        adapter = new Mellow4626VaultAdapter(address(creditManager), vault, stakedPhantomToken);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), vault, "Incorrect targetContract");
        assertEq(adapter.vault(), vault, "Incorrect vault");
        assertEq(adapter.asset(), asset, "Incorrect asset");
    }

    /// @notice U:[M4626-2]: Constructor reverts on invalid multivault
    function test_U_M4626_02_constructor_reverts_on_invalid_multivault() public {
        address wrongVault = makeAddr("WRONG_VAULT");
        vm.mockCall(stakedPhantomToken, abi.encodeWithSignature("multiVault()"), abi.encode(wrongVault));

        vm.expectRevert(IMellow4626VaultAdapter.InvalidMultiVaultException.selector);
        new Mellow4626VaultAdapter(address(creditManager), vault, stakedPhantomToken);
    }

    /// @notice U:[M4626-3]: Wrapper functions revert on wrong caller
    function test_U_M4626_03_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.deposit(0, address(0));

        _revertsOnNonFacadeCaller();
        adapter.depositDiff(0);

        _revertsOnNonFacadeCaller();
        adapter.mint(0, address(0));

        _revertsOnNonFacadeCaller();
        adapter.withdraw(0, address(0), address(0));

        _revertsOnNonFacadeCaller();
        adapter.redeem(0, address(0), address(0));

        _revertsOnNonFacadeCaller();
        adapter.redeemDiff(0);
    }

    /// @notice U:[M4626-4]: `deposit` works as expected
    function test_U_M4626_04_deposit_works_as_expected() public {
        // Test normal deposit
        vm.mockCall(vault, abi.encodeCall(IMellowMultiVault.depositWhitelist, ()), abi.encode(false));
        _readsActiveAccount();
        _executesSwap({
            tokenIn: asset,
            callData: abi.encodeCall(IERC4626.deposit, (1000, creditAccount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.deposit(1000, address(0));
        assertFalse(useSafePrices);
    }

    /// @notice U:[M4626-5]: `depositDiff` works as expected
    function test_U_M4626_05_depositDiff_works_as_expected() public diffTestCases {
        deal({token: asset, to: creditAccount, give: diffMintedAmount});

        // Test normal depositDiff
        vm.mockCall(vault, abi.encodeCall(IMellowMultiVault.depositWhitelist, ()), abi.encode(false));
        _readsActiveAccount();
        _executesSwap({
            tokenIn: asset,
            callData: abi.encodeCall(IERC4626.deposit, (diffInputAmount, creditAccount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositDiff(diffLeftoverAmount);
        assertFalse(useSafePrices);
    }

    /// @notice U:[M4626-6]: `mint` works as expected
    function test_U_M4626_06_mint_works_as_expected() public {
        // Test normal mint
        vm.mockCall(vault, abi.encodeCall(IMellowMultiVault.depositWhitelist, ()), abi.encode(false));
        _readsActiveAccount();
        _executesSwap({
            tokenIn: asset,
            callData: abi.encodeCall(IERC4626.mint, (1000, creditAccount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.mint(1000, address(0));
        assertFalse(useSafePrices);
    }

    /// @notice U:[M4626-7]: `withdraw` works as expected and returns true for safe prices
    function test_U_M4626_07_withdraw_works_as_expected() public {
        _readsActiveAccount();
        _executesSwap({
            tokenIn: vault,
            callData: abi.encodeCall(IERC4626.withdraw, (1000, creditAccount, creditAccount)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdraw(1000, address(0), address(0));
        assertTrue(useSafePrices, "Should use safe prices for withdrawals");
    }

    /// @notice U:[M4626-8]: `redeem` works as expected and returns true for safe prices
    function test_U_M4626_08_redeem_works_as_expected() public {
        _readsActiveAccount();
        _executesSwap({
            tokenIn: vault,
            callData: abi.encodeCall(IERC4626.redeem, (1000, creditAccount, creditAccount)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeem(1000, address(0), address(0));
        assertTrue(useSafePrices, "Should use safe prices for redemptions");
    }

    /// @notice U:[M4626-9]: `redeemDiff` works as expected and returns true for safe prices
    function test_U_M4626_09_redeemDiff_works_as_expected() public diffTestCases {
        deal({token: vault, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: vault,
            callData: abi.encodeCall(IERC4626.redeem, (diffInputAmount, creditAccount, creditAccount)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemDiff(diffLeftoverAmount);
        assertTrue(useSafePrices, "Should use safe prices for redemptions");
    }

    /// @notice U:[M4626-10]: `serialize` works as expected
    function test_U_M4626_10_serialize_works_as_expected() public view {
        bytes memory serialized = adapter.serialize();
        (address cm, address tc, address v, address a) = abi.decode(serialized, (address, address, address, address));

        assertEq(cm, address(creditManager), "Incorrect credit manager in serialized data");
        assertEq(tc, vault, "Incorrect target contract in serialized data");
        assertEq(v, vault, "Incorrect vault in serialized data");
        assertEq(a, asset, "Incorrect asset in serialized data");
    }
}
