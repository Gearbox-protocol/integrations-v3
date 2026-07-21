// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MidasGateway} from "../../../helpers/midas/MidasGateway.sol";
import {MidasRedeemer} from "../../../helpers/midas/MidasRedeemer.sol";

import "./MidasAuditTestBase.sol";

/// @title Midas withdraw accounting invariant tests
/// @notice I:[MID-WD]: Invariant tests proving that gateway `withdraw` preserves funds,
///         never over-pays, and correctly removes settled redeemers from the pending set.
contract MidasWithdrawInvariantTest is MidasAuditTestBase {
    function setUp() public {
        _deployGateway18(true, false, address(0));
    }

    /*
     * @test-id: tst_core_midas_030
     * @scenario: scn_midas_withdraw_multi_001
     * @covers: contracts/helpers/midas/MidasGateway.sol::withdraw
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: MidasGateway with multiple fulfilled redeemers
     * Clients: direct calls
     * Mocks: AuditMidasRedemptionVault
     * Data: 3 redeemers with claimable balances 30/50/20
     *
     * Invariant inv_mid_val_02 / inv_mid_life_02: withdrawing the exact total claimable
     * distributes the sum across the account and removes every fully-drained redeemer.
     */
    function test_tst_core_midas_030_withdraw_exact_total_across_three_redeemers() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 30e18;
        amounts[1] = 50e18;
        amounts[2] = 20e18;
        address[] memory redeemers = _createAndFulfillRedeemers(amounts);

        uint256 totalClaimable = 100e18;
        assertEq(_totalClaimable(redeemers), totalClaimable, "sum of claimable balances");

        vm.prank(address(account));
        gateway.withdraw(totalClaimable);

        assertEq(IERC20(quoteToken18).balanceOf(address(account)), totalClaimable, "account received full total");
        assertEq(gateway.pendingRedeemers(address(account)).length, 0, "all redeemers removed from pending");
    }

    /*
     * @test-id: tst_core_midas_031
     * @scenario: scn_midas_withdraw_partial_001
     * @covers: contracts/helpers/midas/MidasGateway.sol::withdraw
     * @deterministic: yes
     * @fixtures: none
     *
     * Invariant: a partial withdrawal that ends mid-redeemer leaves that redeemer in the
     * pending set with the residual claimable balance, and does not touch later redeemers.
     */
    function test_tst_core_midas_031_partial_withdraw_leaves_residual_in_partially_drained_redeemer() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 30e18;
        amounts[1] = 50e18;
        amounts[2] = 20e18;
        address[] memory redeemers = _createAndFulfillRedeemers(amounts);

        // Withdraw 40e18: drains redeemer[0] (30) fully, then 10 from redeemer[1].
        vm.prank(address(account));
        gateway.withdraw(40e18);

        assertEq(IERC20(quoteToken18).balanceOf(address(account)), 40e18, "account received 40");
        assertEq(IERC20(quoteToken18).balanceOf(redeemers[0]), 0, "redeemer[0] drained");
        assertEq(IERC20(quoteToken18).balanceOf(redeemers[1]), 40e18, "redeemer[1] has 40 left");
        assertEq(IERC20(quoteToken18).balanceOf(redeemers[2]), 20e18, "redeemer[2] untouched");

        // redeemer[0] removed (pending=0, claimable=0); redeemer[1] and [2] stay.
        assertEq(gateway.pendingRedeemers(address(account)).length, 2, "two redeemers remain pending");
    }

    /*
     * @test-id: tst_core_midas_032
     * @scenario: scn_midas_withdraw_skip_pending_001
     * @covers: contracts/helpers/midas/MidasGateway.sol::withdraw
     * @deterministic: yes
     * @fixtures: none
     *
     * Invariant: withdraw skips redeemers that have no claimable balance (still-pending
     * requests) and drains only the fulfilled ones. The pending redeemer stays in the set.
     */
    function test_tst_core_midas_032_withdraw_skips_redeemers_with_zero_claimable_balance() public {
        // Create two redeemers; only fulfill the second one (status=1 + quote tokens).
        _fundAccountWithMToken(2 * 10e18);
        vm.startPrank(address(account));
        gateway.requestRedeem(10e18, "");
        gateway.requestRedeem(10e18, "");
        vm.stopPrank();
        address[] memory redeemers = gateway.pendingRedeemers(address(account));

        // Fulfill only the second redeemer (requestId=1).
        deal(quoteToken18, redeemers[1], 9e18);
        redemptionVault.setStatus(1, 1);

        vm.prank(address(account));
        gateway.withdraw(9e18);

        assertEq(IERC20(quoteToken18).balanceOf(address(account)), 9e18, "account received the fulfilled amount");
        assertEq(IERC20(quoteToken18).balanceOf(redeemers[1]), 0, "fulfilled redeemer drained");
        // First redeemer (still pending, no claim) stays in the set.
        assertEq(gateway.pendingRedeemers(address(account)).length, 1, "pending redeemer stays");
    }

    /*
     * @test-id: tst_core_midas_033
     * @scenario: scn_midas_withdraw_zero_001
     * @covers: contracts/helpers/midas/MidasGateway.sol::withdraw
     * @deterministic: yes
     * @fixtures: none
     *
     * Invariant: withdraw(0) is a no-op that does not revert and does not change state.
     */
    function test_tst_core_midas_033_withdraw_zero_is_a_safe_noop() public {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10e18;
        address[] memory redeemers = _createAndFulfillRedeemers(amounts);

        uint256 pendingBefore = gateway.pendingRedeemers(address(account)).length;
        vm.prank(address(account));
        gateway.withdraw(0);
        assertEq(IERC20(quoteToken18).balanceOf(address(account)), 0, "no tokens moved");
        assertEq(gateway.pendingRedeemers(address(account)).length, pendingBefore, "pending set unchanged");
        assertEq(IERC20(quoteToken18).balanceOf(redeemers[0]), 10e18, "redeemer balance unchanged");
    }

    /*
     * @test-id: tst_core_midas_034
     * @scenario: scn_midas_withdraw_overdraw_001
     * @covers: contracts/helpers/midas/MidasGateway.sol::withdraw
     * @deterministic: yes
     * @fixtures: none
     *
     * Invariant: withdraw reverts when the requested amount exceeds total claimable.
     * No partial state is committed (the loop drains redeemer by redeemer but the final
     * `remainder > 0` check reverts the whole tx, rolling back transfers).
     */
    function test_tst_core_midas_034_withdraw_reverts_when_amount_exceeds_total_claimable() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 30e18;
        amounts[1] = 50e18;
        address[] memory redeemers = _createAndFulfillRedeemers(amounts);

        vm.expectRevert(IMidasGateway.InsufficientBalanceException.selector);
        vm.prank(address(account));
        gateway.withdraw(81e18);

        // State rolled back: account got nothing, redeemers still hold their balances.
        assertEq(IERC20(quoteToken18).balanceOf(address(account)), 0, "no tokens moved on revert");
        assertEq(IERC20(quoteToken18).balanceOf(redeemers[0]), 30e18, "redeemer[0] restored");
        assertEq(IERC20(quoteToken18).balanceOf(redeemers[1]), 50e18, "redeemer[1] restored");
    }

    /*
     * @test-id: tst_core_midas_035
     * @scenario: scn_midas_withdraw_from_redeemer_001
     * @covers: contracts/helpers/midas/MidasGateway.sol::withdrawFromRedeemer
     * @deterministic: yes
     * @fixtures: none
     *
     * Invariant: withdrawFromRedeemer drains a specific redeemer by index and removes it
     * from the pending set only when both pending and claimable are zero afterwards.
     */
    function test_tst_core_midas_035_withdraw_from_redeemer_recovers_from_specific_redeemer() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 30e18;
        amounts[1] = 50e18;
        address[] memory redeemers = _createAndFulfillRedeemers(amounts);

        // Drain only the second redeemer directly.
        vm.prank(address(account));
        gateway.withdrawFromRedeemer(redeemers[1], 50e18);

        assertEq(IERC20(quoteToken18).balanceOf(address(account)), 50e18, "account received 50");
        assertEq(IERC20(quoteToken18).balanceOf(redeemers[1]), 0, "redeemer[1] drained");
        assertEq(IERC20(quoteToken18).balanceOf(redeemers[0]), 30e18, "redeemer[0] untouched");

        // redeemer[1] removed (pending=0, claimable=0); redeemer[0] stays.
        assertEq(gateway.pendingRedeemers(address(account)).length, 1, "only redeemer[0] stays pending");
    }

    /*
     * @test-id: tst_core_midas_036
     * @scenario: scn_midas_withdraw_from_redeemer_not_owner_001
     * @covers: contracts/helpers/midas/MidasGateway.sol::withdrawFromRedeemer
     * @deterministic: yes
     * @fixtures: none
     *
     * Invariant inv_mid_own_02: only the owning account can withdraw from a redeemer.
     */
    function test_tst_core_midas_036_withdraw_from_redeemer_reverts_for_non_owner() public {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 30e18;
        address[] memory redeemers = _createAndFulfillRedeemers(amounts);

        vm.expectRevert(IMidasGateway.RedeemerNotOwnedByAccountException.selector);
        vm.prank(makeAddr("NOT_OWNER"));
        gateway.withdrawFromRedeemer(redeemers[0], 10e18);
    }

    /*
     * @test-id: tst_core_midas_037
     * @scenario: scn_midas_withdraw_atomicity_001
     * @covers: contracts/helpers/midas/MidasGateway.sol::withdraw
     * @deterministic: yes
     * @fixtures: none
     *
     * Invariant: a successful withdraw transfers exactly `amount` to the account (no more,
     * no less), regardless of how the claimable balances are distributed across redeemers.
     */
    function test_tst_core_midas_037_withdraw_transfers_exactly_the_requested_amount() public {
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 7e18;
        amounts[1] = 13e18;
        amounts[2] = 19e18;
        amounts[3] = 23e18;
        _createAndFulfillRedeemers(amounts);

        uint256 requested = 25e18; // drains 7 + 13 + 5 from the third
        uint256 balanceBefore = IERC20(quoteToken18).balanceOf(address(account));
        vm.prank(address(account));
        gateway.withdraw(requested);
        assertEq(
            IERC20(quoteToken18).balanceOf(address(account)) - balanceBefore,
            requested,
            "transferred exactly the requested amount"
        );
    }

    /// @dev Creates `amounts.length` redeemers for `account`, each fulfilled with the given quote balance.
    function _createAndFulfillRedeemers(uint256[] memory amounts) internal returns (address[] memory redeemers) {
        uint256 totalMToken;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalMToken += 10e18;
        }
        _fundAccountWithMToken(totalMToken);
        vm.startPrank(address(account));
        for (uint256 i = 0; i < amounts.length; i++) {
            gateway.requestRedeem(10e18, "");
        }
        vm.stopPrank();
        redeemers = gateway.pendingRedeemers(address(account));
        // Fulfill each: status=1 (Processed) and place quote tokens on the redeemer.
        for (uint256 i = 0; i < amounts.length; i++) {
            redemptionVault.setStatus(uint256(i), 1);
            deal(quoteToken18, redeemers[i], amounts[i]);
        }
    }

    function _totalClaimable(address[] memory redeemers) internal view returns (uint256 total) {
        for (uint256 i = 0; i < redeemers.length; i++) {
            total += IERC20(quoteToken18).balanceOf(redeemers[i]);
        }
    }
}
