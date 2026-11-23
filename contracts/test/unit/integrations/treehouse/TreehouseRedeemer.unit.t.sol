// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {TreehouseRedeemer} from "../../../../integrations/treehouse/TreehouseRedeemer.sol";
import {IWstETH} from "../../../../integrations/treehouse/interfaces/external/IWstETH.sol";
import {TreehouseRedemptionV3Mock} from "./TreehouseRedemptionV3Mock.sol";
import {TreehouseVaultMock} from "./TreehouseRedemptionV3Mock.sol";

/// @title TreehouseRedeemer unit test
/// @notice U:[TH-R]: Unit tests for TreehouseRedeemer
contract TreehouseRedeemerUnitTest is Test {
    TreehouseRedeemer master;
    TreehouseRedeemer redeemer;
    TreehouseRedemptionV3Mock redemptionV3;

    ERC20Mock tAsset;
    ERC20Mock vaultUnderlying;

    address account;

    // redemptionFee (100) + treasuryFee (50) => 1.5% fee on 100e18 => 98.5e18
    uint256 constant SHARES = 100e18;
    uint256 constant AMOUNT_AFTER_FEE = 98.5e18;

    function setUp() public {
        account = makeAddr("ACCOUNT");

        tAsset = new ERC20Mock("tAsset", "tASSET", 18);
        vaultUnderlying = new ERC20Mock("wstETH", "wstETH", 18);

        TreehouseVaultMock vault = new TreehouseVaultMock(address(vaultUnderlying));
        redemptionV3 = new TreehouseRedemptionV3Mock(address(tAsset), address(vault));
        // Liquidity for settlement payouts on finalizeRedeem
        vaultUnderlying.mint(address(redemptionV3), 1_000_000e18);

        // Deploy master with `this` as gateway, then clone like the production gateway
        master = new TreehouseRedeemer(address(redemptionV3), address(tAsset), address(vaultUnderlying));
        redeemer = TreehouseRedeemer(Clones.clone(address(master)));
        redeemer.setAccount(account);

        vm.mockCall(address(tAsset), abi.encodeCall(IERC4626.convertToAssets, (uint256(0))), abi.encode(uint256(0)));
        vm.mockCall(address(vaultUnderlying), abi.encodeCall(IWstETH.stEthPerToken, ()), abi.encode(uint256(1e18)));
    }

    function _seedRedeem(uint256 shares) internal {
        tAsset.mint(address(redeemer), shares);
        redeemer.redeem(shares);
        vm.mockCall(address(tAsset), abi.encodeCall(IERC4626.convertToAssets, (shares)), abi.encode(shares));
    }

    /// @notice U:[TH-R-1]: Constructor and `setAccount` work
    function test_U_TH_R_01_constructor_and_setAccount_work() public view {
        assertEq(redeemer.gateway(), address(this), "Incorrect gateway");
        assertEq(redeemer.redemptionV3(), address(redemptionV3), "Incorrect redemptionV3");
        assertEq(redeemer.tAsset(), address(tAsset), "Incorrect tAsset");
        assertEq(redeemer.vaultUnderlying(), address(vaultUnderlying), "Incorrect vaultUnderlying");
        assertEq(redeemer.account(), account, "Incorrect account");
        assertFalse(redeemer.alreadyRedeemed(), "Should not be redeemed yet");
    }

    /// @notice U:[TH-R-2]: Gateway-only functions revert for wrong caller
    function test_U_TH_R_02_gateway_only_functions_revert_on_wrong_caller() public {
        vm.prank(makeAddr("NOT_GATEWAY"));
        vm.expectRevert(TreehouseRedeemer.CallerNotGatewayException.selector);
        redeemer.setAccount(account);

        vm.prank(makeAddr("NOT_GATEWAY"));
        vm.expectRevert(TreehouseRedeemer.CallerNotGatewayException.selector);
        redeemer.redeem(1);

        vm.prank(makeAddr("NOT_GATEWAY"));
        vm.expectRevert(TreehouseRedeemer.CallerNotGatewayException.selector);
        redeemer.finalizeRedeem();

        vm.prank(makeAddr("NOT_GATEWAY"));
        vm.expectRevert(TreehouseRedeemer.CallerNotGatewayException.selector);
        redeemer.rescueToken(address(tAsset));
    }

    /// @notice U:[TH-R-3]: `redeem` works and can only be called once
    function test_U_TH_R_03_redeem_works_once() public {
        tAsset.mint(address(redeemer), SHARES);

        redeemer.redeem(SHARES);
        assertTrue(redeemer.alreadyRedeemed(), "Should be marked redeemed");
        assertEq(redemptionV3.getRedeemLength(address(redeemer)), 1, "Redemption not recorded");
        assertEq(tAsset.balanceOf(address(redemptionV3)), SHARES, "tAsset not pulled by redemptionV3");

        vm.expectRevert(TreehouseRedeemer.AlreadyRedeemedException.selector);
        redeemer.redeem(1);
    }

    /// @notice U:[TH-R-4]: `finalizeRedeem` receives underlying from the redemption contract and forwards it
    function test_U_TH_R_04_finalizeRedeem_works() public {
        _seedRedeem(SHARES);

        redeemer.finalizeRedeem();
        assertEq(vaultUnderlying.balanceOf(account), AMOUNT_AFTER_FEE, "Underlying not sent to account");
        assertEq(vaultUnderlying.balanceOf(address(redeemer)), 0, "Redeemer should not retain underlying");
        assertEq(redemptionV3.getRedeemLength(address(redeemer)), 0, "Redemption not cleared");
    }

    /// @notice U:[TH-R-5]: `rescueToken` transfers the full token balance to the account
    function test_U_TH_R_05_rescueToken_works() public {
        ERC20Mock reward = new ERC20Mock("REWARD", "RWD", 18);
        reward.mint(address(redeemer), 42e18);

        redeemer.rescueToken(address(reward));
        assertEq(reward.balanceOf(account), 42e18, "Reward not rescued");
        assertEq(reward.balanceOf(address(redeemer)), 0, "Redeemer still holds reward");
    }

    /// @notice U:[TH-R-6]: `pendingAmount` / `claimableAmount` respect the waiting period
    function test_U_TH_R_06_pending_and_claimable_amounts() public {
        _seedRedeem(SHARES);

        assertEq(redeemer.pendingAmount(), AMOUNT_AFTER_FEE, "Incorrect pending before maturity");
        assertEq(redeemer.claimableAmount(), 0, "Claimable should be zero before maturity");

        vm.warp(block.timestamp + redemptionV3.waitingPeriod());

        assertEq(redeemer.pendingAmount(), 0, "Pending should be zero after maturity");
        assertEq(redeemer.claimableAmount(), AMOUNT_AFTER_FEE, "Incorrect claimable after maturity");
    }
}
