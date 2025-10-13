// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC4626Referral} from "../../../../integrations/erc4626/IERC4626Referral.sol";
import {ERC4626Adapter} from "../../../../adapters/erc4626/ERC4626Adapter.sol";
import {ERC4626ReferralAdapter} from "../../../../adapters/erc4626/ERC4626ReferralAdapter.sol";
import {Mellow4626VaultAdapter} from "../../../../adapters/mellow/Mellow4626VaultAdapter.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title ERC-4626 adapter unit test
/// @notice U:[TV]: Unit tests for ERC-4626 tokenized vault adapter
contract ERC4626AdapterUnitTest is AdapterUnitTestHelper {
    ERC4626Adapter adapter;

    address asset;
    address vault;
    address gateway;

    function setUp() public {
        _setUp();

        asset = tokens[0];
        vault = tokens[1];
        gateway = tokens[2];

        vm.mockCall(vault, abi.encodeCall(IERC4626.asset, ()), abi.encode(asset));

        adapter = new ERC4626Adapter(address(creditManager), vault, address(0));
    }

    /// @notice U:[TV-1]: Constructor works as expected
    function test_U_TV_01_constructor_works_as_expected() public {
        _readsTokenMask(asset);
        _readsTokenMask(vault);
        adapter = new ERC4626Adapter(address(creditManager), vault, address(0));

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), vault, "Incorrect targetContract");
        assertEq(adapter.vault(), vault, "Incorrect vault");
        assertEq(adapter.asset(), asset, "Incorrect asset");

        adapter = new ERC4626Adapter(address(creditManager), vault, gateway);
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), gateway, "Incorrect targetContract");
        assertEq(adapter.vault(), vault, "Incorrect vault");
        assertEq(adapter.asset(), asset, "Incorrect asset");
    }

    /// @notice U:[TV-2]: Wrapper functions revert on wrong caller
    function test_U_TV_02_wrapper_functions_revert_on_wrong_caller() public {
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

    /// @notice U:[TV-3]: `deposit` works as expected
    function test_U_TV_03_deposit_works_as_expected() public {
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

    /// @notice U:[TV-4]: `depositDiff` works as expected
    function test_U_TV_04_depositDiff_works_as_expected() public diffTestCases {
        deal({token: asset, to: creditAccount, give: diffMintedAmount});

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

    /// @notice U:[TV-5]: `mint` works as expected
    function test_U_TV_05_mint_works_as_expected() public {
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

    /// @notice U:[TV-6]: `withdraw` works as expected
    function test_U_TV_06_withdraw_works_as_expected() public {
        _readsActiveAccount();
        _executesSwap({
            tokenIn: vault,
            callData: abi.encodeCall(IERC4626.withdraw, (1000, creditAccount, creditAccount)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdraw(1000, address(0), address(0));
        assertFalse(useSafePrices);
    }

    /// @notice U:[TV-7]: `redeem` works as expected
    function test_U_TV_07_redeem_works_as_expected() public {
        _readsActiveAccount();
        _executesSwap({
            tokenIn: vault,
            callData: abi.encodeCall(IERC4626.redeem, (1000, creditAccount, creditAccount)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeem(1000, address(0), address(0));
        assertFalse(useSafePrices);
    }

    /// @notice U:[TV-8]: `redeemDiff` works as expected
    function test_U_TV_08_redeemDiff_works_as_expected() public diffTestCases {
        deal({token: vault, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: vault,
            callData: abi.encodeCall(IERC4626.redeem, (diffInputAmount, creditAccount, creditAccount)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemDiff(diffLeftoverAmount);
        assertFalse(useSafePrices);
    }

    function test_U_TV_09_referral_adapter_works_as_expected() public diffTestCases {
        deal({token: asset, to: creditAccount, give: diffMintedAmount});

        adapter = new ERC4626ReferralAdapter(address(creditManager), vault, 1);

        _executesSwap({
            tokenIn: asset,
            callData: abi.encodeCall(IERC4626Referral.deposit, (1000, creditAccount, 1)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        adapter.deposit(1000, address(0));

        _executesSwap({
            tokenIn: asset,
            callData: abi.encodeCall(IERC4626Referral.mint, (1000, creditAccount, 1)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        adapter.mint(1000, address(0));

        _executesSwap({
            tokenIn: asset,
            callData: abi.encodeCall(IERC4626Referral.deposit, (diffInputAmount, creditAccount, 1)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        adapter.depositDiff(diffLeftoverAmount);
    }
}
