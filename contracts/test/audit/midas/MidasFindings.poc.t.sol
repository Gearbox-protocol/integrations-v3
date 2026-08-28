// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MidasGateway} from "../../../helpers/midas/MidasGateway.sol";
import {MidasRedeemer} from "../../../helpers/midas/MidasRedeemer.sol";
import {MidasRedemptionVaultPhantomToken} from "../../../helpers/midas/MidasRedemptionVaultPhantomToken.sol";

import "./MidasAuditTestBase.sol";

/// @title Midas findings PoC tests
/// @notice P:[MID-FIND]: Proof-of-concept tests for confirmed audit findings.
contract MidasFindingsPoCTest is MidasAuditTestBase {
    function setUp() public {
        _deployGateway18(true, false, address(0));
    }

    /*
     * @test-id: tst_core_midas_001
     * @scenario: scn_midas_saved_rate_001
     * @covers: contracts/helpers/midas/MidasRedemptionVaultPhantomToken.sol::balanceOf
     *          contracts/helpers/midas/MidasRedeemer.sol::pendingTokenOutAmount
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: MidasGateway with configurable data feed
     * Clients: direct calls
     * Mocks: AuditMidasRedemptionVault, AuditMidasDataFeed
     * Data: 100e18 mToken request, mToken rate doubles after request
     *
     * Finding MID-R01: phantom uses the CURRENT mToken data feed rate, while Midas may settle
     * at the request-time SAVED rate. When the mToken rate appreciates, the phantom balance
     * exceeds the amount Midas will actually deliver, inflating borrowing capacity.
     */
    function test_tst_core_midas_001_phantom_overvalues_when_mtoken_rate_grows_vs_saved_rate() public {
        uint256 amountMTokenIn = 100e18;
        address redeemer = _requestRedeemFromAccount(amountMTokenIn);

        assertEq(phantomToken.balanceOf(address(account)), 100e18, "initial phantom value");

        // mToken rate doubles; tokenOutRate stays snapshotted at 1e18.
        dataFeed.setRate(2e18);
        assertEq(phantomToken.balanceOf(address(account)), 200e18, "phantom grows with current rate");

        // Saved-rate settlement (what Midas would deliver if it settles at request-time rates):
        // stored mTokenRate = 1e18, stored tokenOutRate = 1e18 => 100e18 quote only.
        (,,, uint256 storedAmount, uint256 storedMTokenRate, uint256 storedTokenOutRate) =
            redemptionVault.redeemRequests(MidasRedeemer(redeemer).requestId());
        uint256 savedRateSettlement = (storedAmount * storedMTokenRate) / storedTokenOutRate;
        assertEq(savedRateSettlement, 100e18, "saved-rate settlement is only 100e18");
        assertGt(
            phantomToken.balanceOf(address(account)),
            savedRateSettlement,
            "phantom overstates realizable settlement (MID-R01)"
        );
    }

    /*
     * @test-id: tst_core_midas_002
     * @scenario: scn_midas_cancel_001
     * @covers: contracts/helpers/midas/MidasRedeemer.sol::pendingTokenOutAmount
     *          contracts/helpers/midas/MidasRedemptionVaultPhantomToken.sol::balanceOf
     * @deterministic: yes
     * @fixtures: none
     *
     * Finding MID-R02: when Midas cancels a request (status = 2) without returning the mToken
     * and without anyone manually clearing it, the phantom still reports the full projected
     * value. The credit account can borrow against collateral with no enforceable recovery.
     */
    function test_tst_core_midas_002_cancelled_request_retains_unbacked_phantom_value() public {
        uint256 amountMTokenIn = 100e18;
        address redeemer = _requestRedeemFromAccount(amountMTokenIn);

        // mToken has left the redeemer and is held by the vault
        assertEq(IERC20(mToken).balanceOf(redeemer), 0, "mToken already pulled by vault");
        assertEq(IERC20(mToken).balanceOf(address(redemptionVault)), amountMTokenIn, "vault holds the mToken");

        // Midas rejects the request: status -> Canceled (2). No quote is sent to the redeemer.
        redemptionVault.setStatus(0, 2);

        assertEq(IERC20(quoteToken18).balanceOf(redeemer), 0, "redeemer holds no quote token");

        uint256 phantomValue = phantomToken.balanceOf(address(account));
        assertGt(phantomValue, 0, "phantom retains value after cancellation (MID-R02)");
        assertEq(phantomValue, 100e18, "phantom reports full projected value with no backing asset");
        assertFalse(MidasRedeemer(redeemer).isManuallyCleared(), "no manual clearing has occurred");
    }

    /*
     * @test-id: tst_core_midas_007
     * @scenario: scn_midas_transfer_cap_001
     * @covers: contracts/helpers/midas/MidasGateway.sol::transferRedeemer
     * @deterministic: yes
     * @fixtures: none
     *
     * Finding MID-R06: transferRedeemer does not check the 10-pending cap on the destination.
     * Repeated transfers can push an account above MAX_PENDING_REDEEMERS_PER_ACCOUNT, causing
     * unbounded gas in withdraw / pendingAndClaimableTokenOutAmounts.
     */
    function test_tst_core_midas_007_transfer_can_exceed_max_pending_redeemers_on_destination() public {
        AuditCreditAccount accountB = new AuditCreditAccount(address(creditManager));
        creditManager.setBorrower(address(accountB), makeAddr("BORROWER_B"));

        // Give B one pending redeemer so B starts at 1/10.
        deal(mToken, address(accountB), 1e18);
        vm.prank(address(accountB));
        accountB.approveToken(mToken, address(gateway), 1e18);
        vm.prank(address(accountB));
        gateway.requestRedeem(1e18, "");
        assertEq(gateway.pendingRedeemers(address(accountB)).length, 1, "B starts with 1 redeemer");

        // Create 10 redeemers on A (the maximum allowed by the creation cap).
        _fundAccountWithMToken(10 * 1e18);
        vm.startPrank(address(account));
        for (uint256 i = 0; i < 10; i++) {
            gateway.requestRedeem(1e18, "");
        }
        vm.stopPrank();
        assertEq(gateway.pendingRedeemers(address(account)).length, 10, "A is at the 10 cap");

        // Enable transfers (simulating a liquidation window).
        _setTransferAllowed(true);

        // Transfer all 10 of A's redeemers to B — cap is NOT checked on the destination.
        address[] memory aRedeemers = gateway.pendingRedeemers(address(account));
        vm.startPrank(address(account));
        for (uint256 i = 0; i < aRedeemers.length; i++) {
            gateway.transferRedeemer(aRedeemers[i], address(accountB));
        }
        vm.stopPrank();

        assertGt(
            gateway.pendingRedeemers(address(accountB)).length,
            10,
            "destination cap not enforced on transfer (MID-R06)"
        );
        assertEq(gateway.pendingRedeemers(address(accountB)).length, 11, "B has 11 pending redeemers");
    }

    /*
     * @test-id: tst_core_midas_010
     * @scenario: scn_midas_transfer_scope_001
     * @covers: contracts/helpers/midas/MidasGateway.sol::transferRedeemer
     *          contracts/helpers/midas/MidasLiquidator.sol::isTransferAllowed
     * @deterministic: yes
     * @fixtures: none
     *
     * Finding MID-R09: isTransferAllowed is a single global boolean, not scoped to the account
     * being liquidated. While account A's liquidation raises the flag, any other eligible
     * account B can transfer its own redeemers to a new account even though B is not under
     * liquidation, letting a borrower move positions outside a liquidation window.
     */
    function test_tst_core_midas_010_transfer_flag_is_global_not_scoped_to_liquidated_account() public {
        _requestRedeemFromAccount(50e18);

        // Account B is a separate, healthy credit account with its own redeemer.
        AuditCreditAccount accountB = new AuditCreditAccount(address(creditManager));
        creditManager.setBorrower(address(accountB), makeAddr("BORROWER_B"));
        deal(mToken, address(accountB), 50e18);
        vm.prank(address(accountB));
        accountB.approveToken(mToken, address(gateway), 50e18);
        vm.prank(address(accountB));
        gateway.requestRedeem(50e18, "");
        address redeemerB = gateway.pendingRedeemers(address(accountB))[0];

        // Simulate account A's liquidation raising the global transfer flag.
        _setTransferAllowed(true);

        // Account B (NOT being liquidated) transfers its own redeemer to a brand-new account.
        AuditCreditAccount accountC = new AuditCreditAccount(address(creditManager));
        creditManager.setBorrower(address(accountC), makeAddr("BORROWER_C"));

        vm.prank(address(accountB));
        gateway.transferRedeemer(redeemerB, address(accountC));

        assertEq(gateway.pendingRedeemers(address(accountB)).length, 0, "B's redeemer was transferred out");
        assertEq(gateway.pendingRedeemers(address(accountC)).length, 1, "C received B's redeemer (MID-R09)");
        assertEq(MidasRedeemer(redeemerB).account(), address(accountC), "redeemer account updated to C");
    }

    /*
     * @test-id: tst_core_midas_012
     * @scenario: scn_midas_status_001
     * @covers: contracts/helpers/midas/MidasRedeemer.sol::pendingTokenOutAmount
     * @deterministic: yes
     * @fixtures: none
     *
     * Finding MID-R10: pendingTokenOutAmount only treats status == 1 (Processed) and
     * isManuallyCleared as terminal. Any other status (including Cancel=2 and unknown future
     * values) is treated as pending and valued at the live mToken rate. A future Midas status
     * meaning "no value" would keep reporting phantom collateral until manual intervention.
     */
    function test_tst_core_midas_012_unknown_status_treated_as_pending_and_overvalued() public {
        uint256 amountMTokenIn = 100e18;
        address redeemer = _requestRedeemFromAccount(amountMTokenIn);

        // Simulate a future Midas status value (e.g. 99 = "Failed/Revoked").
        redemptionVault.setStatus(0, 99);

        uint256 pending = MidasRedeemer(redeemer).pendingTokenOutAmount();
        assertGt(pending, 0, "unknown status still valued as pending (MID-R10)");
        assertEq(pending, 100e18, "unknown status valued at full live-rate amount");

        // Phantom follows the same path, so collateral value stays positive.
        assertGt(phantomToken.balanceOf(address(account)), 0, "phantom reports value for unknown status");
    }

    /*
     * @test-id: tst_core_midas_018
     * @scenario: scn_midas_sweep_donation_001
     * @covers: contracts/helpers/midas/MidasGateway.sol::_sweepTokens
     *          contracts/helpers/midas/MidasGateway.sol::depositInstant
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: MidasGateway with a pre-existing donated quote-token balance
     * Clients: direct calls
     * Mocks: AuditMidasIssuanceVault, AuditMidasRedemptionVault
     * Data: 50e18 donated quote, 10e18 deposit
     *
     * NEW FINDING (introduced by the sweeping fix in 7eaa0db): `_sweepTokens` transfers the
     * ENTIRE gateway balance of both tokens, not just the balance delta produced by the current
     * operation. The old code used `balanceAfter - balanceBefore` which was safe against
     * pre-existing balances. The new code sweeps any pre-existing balance (donation, dust from
     * a prior operation, or residual from a reverted sub-call) to the current caller.
     *
     * If an attacker donates quote tokens to the gateway, the next credit account that calls
     * `depositInstant` receives the donated amount on top of its normal mToken output.
     * Symmetrically, a donated mToken balance is swept to the next `redeemInstant` caller.
     */
    function test_tst_core_midas_018_sweeptokens_sweeps_preexisting_donation_to_next_caller() public {
        // 1. Donate 50e18 quote to the gateway (simulates a prior donation or stranded dust).
        uint256 donation = 50e18;
        deal(quoteToken18, address(gateway), donation);

        // 2. Account deposits 10e18 quote; vault issues 10e18 mToken (1:1).
        uint256 depositAmount = 10e18;
        _fundAccountWithQuote(depositAmount);
        deal(mToken, address(issuanceVault), 10e18);
        issuanceVault.setMTokenAmountOut(10e18);

        uint256 accountQuoteBefore = IERC20(quoteToken18).balanceOf(address(account));
        vm.prank(address(account));
        gateway.depositInstant(depositAmount, 0, bytes32(0));

        // 3. The account received the 10e18 mToken output...
        assertEq(IERC20(mToken).balanceOf(address(account)), 10e18, "account received mToken output");

        // 4. ...AND the 50e18 donated quote, because _sweepTokens sweeps the entire balance.
        //    The account spent 10e18 quote on the deposit, but got 50e18 back from the sweep.
        uint256 accountQuoteAfter = IERC20(quoteToken18).balanceOf(address(account));
        assertEq(accountQuoteAfter + depositAmount - accountQuoteBefore, donation, "account swept the donated quote (new finding)");
        assertEq(IERC20(quoteToken18).balanceOf(address(gateway)), 0, "gateway fully drained");

        // The donation was moved from the gateway to the caller's credit account. Under the
        // old balance-delta accounting, the donation would have stayed on the gateway.
    }

    /*
     * @test-id: tst_core_midas_019
     * @scenario: scn_midas_sweep_donation_002
     * @covers: contracts/helpers/midas/MidasGateway.sol::_sweepTokens
     *          contracts/helpers/midas/MidasGateway.sol::redeemInstant
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: MidasGateway with a pre-existing donated mToken balance
     * Clients: direct calls
     * Mocks: AuditMidasRedemptionVault
     * Data: 50e18 donated mToken, 10e18 instant redemption
     *
     * NEW FINDING (symmetric to 018): a donated mToken balance is swept to the next
     * `redeemInstant` caller on top of their normal quote-token output.
     */
    function test_tst_core_midas_019_sweeptokens_sweeps_preexisting_mtoken_donation_to_next_caller() public {
        // 1. Donate 50e18 mToken to the gateway.
        uint256 donation = 50e18;
        deal(mToken, address(gateway), donation);

        // 2. Account instant-redeems 10e18 mToken; vault sends 10e18 quote (1:1).
        _fundAccountWithMToken(10e18);
        deal(quoteToken18, address(redemptionVault), 10e18);
        redemptionVault.setTokenOutAmount(10e18);

        uint256 accountMTokenBefore = IERC20(mToken).balanceOf(address(account));
        vm.prank(address(account));
        gateway.redeemInstant(10e18, 0);

        // 3. The account received the 10e18 quote output...
        assertEq(IERC20(quoteToken18).balanceOf(address(account)), 10e18, "account received quote output");

        // 4. ...AND the 50e18 donated mToken, because _sweepTokens sweeps the entire mToken balance.
        //    The account spent 10e18 mToken on the redemption, but got 50e18 back from the sweep.
        uint256 accountMTokenAfter = IERC20(mToken).balanceOf(address(account));
        assertEq(accountMTokenAfter + 10e18 - accountMTokenBefore, donation, "account swept the donated mToken (new finding)");
        assertEq(IERC20(mToken).balanceOf(address(gateway)), 0, "gateway fully drained");
    }
}
