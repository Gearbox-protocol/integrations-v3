// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {MellowDVVAdapter} from "../../../../adapters/mellow/MellowDVVAdapter.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title MellowDVVAdapter unit test
/// @notice U:[MDVV]: Unit tests for MellowDVVAdapter
contract MellowDVVAdapterUnitTest is AdapterUnitTestHelper {
    MellowDVVAdapter adapter;
    address vault;
    address asset;

    function setUp() public {
        _setUp();
        asset = tokens[0];
        vault = tokens[1];

        vm.mockCall(vault, abi.encodeCall(IERC4626.asset, ()), abi.encode(asset));

        adapter = new MellowDVVAdapter(address(creditManager), vault);
    }

    /// @notice U:[MDVV-1]: Constructor works as expected
    function test_U_MDVV_01_constructor_works_as_expected() public view {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), vault, "Incorrect targetContract");
    }

    /// @notice U:[MDVV-2]: Wrapper functions revert on wrong caller
    function test_U_MDVV_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.deposit(1000, address(0));

        _revertsOnNonFacadeCaller();
        adapter.mint(1000, address(0));
    }

    /// @notice U:[MDVV-3]: Deposit and mint revert as not implemented
    function test_U_MDVV_03_deposit_and_mint_revert() public {
        vm.prank(creditFacade);
        vm.expectRevert(NotImplementedException.selector);
        adapter.deposit(1000, address(0));

        vm.prank(creditFacade);
        vm.expectRevert(NotImplementedException.selector);
        adapter.mint(1000, address(0));
    }

    /// @notice U:[MDVV-4]: Inherited withdraw works as expected
    function test_U_MDVV_04_inherited_withdraw_works_as_expected() public {
        _revertsOnNonFacadeCaller();
        adapter.withdraw(1000, address(0), address(0));

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

    /// @notice U:[MDVV-5]: Inherited redeem works as expected
    function test_U_MDVV_05_inherited_redeem_works_as_expected() public {
        _revertsOnNonFacadeCaller();
        adapter.redeem(1000, address(0), address(0));

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

    /// @notice U:[MDVV-6]: Inherited redeemDiff works as expected
    function test_U_MDVV_06_inherited_redeemDiff_works_as_expected() public diffTestCases {
        _revertsOnNonFacadeCaller();
        adapter.redeemDiff(1000);

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
}
