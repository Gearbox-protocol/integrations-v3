// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpshiftVaultAdapter} from "../../../../adapters/upshift/UpshiftVaultAdapter.sol";
import {UpshiftVaultGateway} from "../../../../helpers/upshift/UpshiftVaultGateway.sol";
import {IUpshiftVaultGateway} from "../../../../interfaces/upshift/IUpshiftVaultGateway.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IPhantomTokenAdapter} from "../../../../interfaces/IPhantomTokenAdapter.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title UpshiftVault adapter unit test
/// @notice U:[UV]: Unit tests for UpshiftVault adapter
contract UpshiftVaultAdapterUnitTest is AdapterUnitTestHelper {
    UpshiftVaultAdapter adapter;

    address gateway;
    address vault;
    address asset;
    address stakedPhantomToken;

    function setUp() public {
        _setUp();

        asset = tokens[0];
        vault = tokens[1];
        stakedPhantomToken = tokens[2];

        vm.mockCall(vault, abi.encodeCall(IERC4626.asset, ()), abi.encode(asset));

        gateway = address(new UpshiftVaultGateway(vault));

        adapter = new UpshiftVaultAdapter(address(creditManager), gateway, stakedPhantomToken);
    }

    /// @notice U:[UV-1]: Constructor works as expected
    function test_U_UV_01_constructor_works_as_expected() public {
        _readsTokenMask(asset);
        _readsTokenMask(vault);
        _readsTokenMask(stakedPhantomToken);

        adapter = new UpshiftVaultAdapter(address(creditManager), gateway, stakedPhantomToken);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), gateway, "Incorrect targetContract");
        assertEq(adapter.asset(), asset, "Incorrect asset");
        assertEq(adapter.stakedPhantomToken(), stakedPhantomToken, "Incorrect stakedPhantomToken");
        assertEq(adapter.vault(), vault, "Incorrect vaultToken");
    }

    /// @notice U:[UV-2]: Wrapper functions revert on wrong caller
    function test_U_UV_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.requestRedeem(1000);

        _revertsOnNonFacadeCaller();
        adapter.claim(1000);

        _revertsOnNonFacadeCaller();
        adapter.withdrawPhantomToken(address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.depositPhantomToken(address(0), 0);
    }

    /// @notice U:[UV-3]: Direct withdraw/redeem functions revert as expected
    function test_U_UV_03_direct_withdraw_redeem_revert() public {
        vm.prank(creditFacade);
        vm.expectRevert(NotImplementedException.selector);
        adapter.withdraw(1000, address(0), address(0));

        vm.prank(creditFacade);
        vm.expectRevert(NotImplementedException.selector);
        adapter.redeem(1000, address(0), address(0));
    }

    /// @notice U:[UV-4]: `requestRedeem` works as expected
    function test_U_UV_04_requestRedeem_works_as_expected() public {
        _executesSwap({
            tokenIn: vault,
            callData: abi.encodeCall(IUpshiftVaultGateway.requestRedeem, (1000)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.requestRedeem(1000);
        assertTrue(useSafePrices);
    }
    /// @notice U:[UV-8]: `requestRedeemDiff` works as expected

    function test_U_UV_08_requestRedeemDiff_works_as_expected() public diffTestCases {
        deal({token: vault, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: vault,
            callData: abi.encodeCall(IUpshiftVaultGateway.requestRedeem, (diffInputAmount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.requestRedeemDiff(diffLeftoverAmount);
        assertTrue(useSafePrices);
    }

    /// @notice U:[UV-5]: `claim` works as expected
    function test_U_UV_05_claim_works_as_expected() public {
        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IUpshiftVaultGateway.claim, (1000)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.claim(1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[UV-6]: `withdrawPhantomToken` works as expected
    function test_U_UV_06_withdrawPhantomToken_works_as_expected() public {
        // Test with incorrect token
        vm.expectRevert(IPhantomTokenAdapter.IncorrectStakedPhantomTokenException.selector);
        vm.prank(creditFacade);
        adapter.withdrawPhantomToken(address(0), 1000);

        // Test with correct token
        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IUpshiftVaultGateway.claim, (1000)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawPhantomToken(stakedPhantomToken, 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[UV-7]: `depositPhantomToken` reverts as expected
    function test_U_UV_07_depositPhantomToken_reverts() public {
        vm.prank(creditFacade);
        vm.expectRevert(NotImplementedException.selector);
        adapter.depositPhantomToken(stakedPhantomToken, 1000);
    }
}
