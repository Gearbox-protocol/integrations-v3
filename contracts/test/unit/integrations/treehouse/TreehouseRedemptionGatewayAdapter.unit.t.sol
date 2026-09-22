// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {
    TreehouseRedemptionGatewayAdapter
} from "../../../../integrations/treehouse/TreehouseRedemptionGatewayAdapter.sol";
import {
    ITreehouseRedemptionGateway
} from "../../../../integrations/treehouse/interfaces/ITreehouseRedemptionGateway.sol";

import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @dev Minimal gateway mock — the adapter reads immutable token addresses from it.
contract TreehouseRedemptionGatewayMock {
    address public immutable tAsset;
    address public immutable vaultUnderlying;
    address public immutable phantomToken;

    constructor(address tAsset_, address vaultUnderlying_, address phantomToken_) {
        tAsset = tAsset_;
        vaultUnderlying = vaultUnderlying_;
        phantomToken = phantomToken_;
    }
}

/// @title Treehouse Redemption Gateway adapter unit test
/// @notice U:[TH-A]: Unit tests for TreehouseRedemptionGatewayAdapter
contract TreehouseRedemptionGatewayAdapterUnitTest is AdapterUnitTestHelper {
    TreehouseRedemptionGatewayAdapter adapter;
    TreehouseRedemptionGatewayMock gateway;

    address tAsset;
    address vaultUnderlying;
    address phantomToken;

    function setUp() public {
        _setUp();

        tAsset = tokens[0];
        vaultUnderlying = tokens[1];
        phantomToken = tokens[2];

        gateway = new TreehouseRedemptionGatewayMock(tAsset, vaultUnderlying, phantomToken);
        adapter = new TreehouseRedemptionGatewayAdapter(address(creditManager), address(gateway));
    }

    /// @notice U:[TH-A-1]: Constructor works as expected
    function test_U_TH_A_01_constructor_works_as_expected() public {
        _readsTokenMask(tAsset);
        _readsTokenMask(vaultUnderlying);
        _readsTokenMask(phantomToken);

        adapter = new TreehouseRedemptionGatewayAdapter(address(creditManager), address(gateway));

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), address(gateway), "Incorrect targetContract");
        assertEq(adapter.tAsset(), tAsset, "Incorrect tAsset");
        assertEq(adapter.vaultUnderlying(), vaultUnderlying, "Incorrect vaultUnderlying");
        assertEq(adapter.phantomToken(), phantomToken, "Incorrect phantomToken");
        assertEq(adapter.contractType(), "ADAPTER::TREEHOUSE_GATEWAY", "Incorrect contract type");
        assertEq(adapter.version(), 3_10, "Incorrect version");
    }

    /// @notice U:[TH-A-2]: Wrapper functions revert on wrong caller
    function test_U_TH_A_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.redeem(1000);

        _revertsOnNonFacadeCaller();
        adapter.redeem(1000, "");

        _revertsOnNonFacadeCaller();
        adapter.redeemDiff(100);

        _revertsOnNonFacadeCaller();
        adapter.redeemDiff(100, "");

        _revertsOnNonFacadeCaller();
        adapter.finalizeRedeem(makeAddr("REDEEMER"));

        _revertsOnNonFacadeCaller();
        adapter.transferRedeemer(makeAddr("REDEEMER"), makeAddr("NEW_ACCOUNT"));

        _revertsOnNonFacadeCaller();
        adapter.rescueToken(makeAddr("REDEEMER"), makeAddr("TOKEN"));

        _revertsOnNonFacadeCaller();
        adapter.withdrawPhantomToken(address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.depositPhantomToken(address(0), 0);
    }

    /// @notice U:[TH-A-3]: `redeem` works as expected
    function test_U_TH_A_03_redeem_works_as_expected() public {
        uint256 shares = 1_234;

        _executesSwap({
            tokenIn: tAsset,
            callData: abi.encodeCall(ITreehouseRedemptionGateway.redeem, (shares, "")),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        assertTrue(adapter.redeem(shares));
    }

    /// @notice U:[TH-A-4]: `finalizeRedeem` works as expected
    function test_U_TH_A_04_finalizeRedeem_works_as_expected() public {
        address redeemer = makeAddr("REDEEMER");

        _executesCall(new address[](0), abi.encodeCall(ITreehouseRedemptionGateway.finalizeRedeem, (redeemer)));

        vm.prank(creditFacade);
        assertTrue(adapter.finalizeRedeem(redeemer));
    }

    /// @notice U:[TH-A-5]: `transferRedeemer` works as expected
    function test_U_TH_A_05_transferRedeemer_works_as_expected() public {
        address redeemer = makeAddr("REDEEMER");
        address newAccount = makeAddr("NEW_ACCOUNT");

        _executesCall(
            new address[](0), abi.encodeCall(ITreehouseRedemptionGateway.transferRedeemer, (redeemer, newAccount))
        );

        vm.prank(creditFacade);
        assertTrue(adapter.transferRedeemer(redeemer, newAccount));
    }

    /// @notice U:[TH-A-6]: `rescueToken` works as expected
    function test_U_TH_A_06_rescueToken_works_as_expected() public {
        address redeemer = makeAddr("REDEEMER");
        address token = makeAddr("TOKEN");

        _executesCall(new address[](0), abi.encodeCall(ITreehouseRedemptionGateway.rescueToken, (redeemer, token)));

        vm.prank(creditFacade);
        assertTrue(adapter.rescueToken(redeemer, token));
    }

    /// @notice U:[TH-A-7]: phantom token deposit/withdraw are not implemented
    function test_U_TH_A_07_phantom_token_hooks_revert() public {
        vm.prank(creditFacade);
        vm.expectRevert(NotImplementedException.selector);
        adapter.withdrawPhantomToken(address(0), 0);

        vm.prank(creditFacade);
        vm.expectRevert(NotImplementedException.selector);
        adapter.depositPhantomToken(address(0), 0);
    }
}
