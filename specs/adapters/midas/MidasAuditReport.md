# Midas integration — audit report

**Scope:** `contracts/adapters/midas/MidasGatewayAdapter.sol`,
`contracts/helpers/midas/{MidasGateway,MidasRedeemer,MidasLiquidator,MidasRedemptionVaultPhantomToken}.sol`,
`contracts/integrations/midas/*`, `contracts/interfaces/midas/*`.

**Gearbox revision reviewed:** `dc1d8b5` (branch `midas-rwa`, pulled during this audit pass).

**Midas revision reviewed:** `90a5f24626253c8f08685f9b238056aadf8625ce` (cloned from
`midas-apps/contracts` at `~/Coding/midas`). All Midas claims in this report are verified
against the actual `RedemptionVault.sol` / `DepositVault.sol` / `ManageableVault.sol` source,
not against the research-document assertions alone.

**Upstream commits pulled during this audit pass:**
- `7eaa0db feat: midas full token sweeping for instant functions + midas / securitize takes RL address from AP`
- `dc1d8b5 fix: midas token sweeping improvements`

These replace the `balanceAfter - balanceBefore` delta accounting in
`MidasGateway.depositInstant`/`redeemInstant` with `_sweepTokens(msg.sender)` (transfers the
entire gateway balance of both tokens), add `_sweepMToken()` to `MidasRedeemer.requestRedeem`,
and change the gateway constructor signature: `_redemptionLogger` → `_addressProvider` (the
logger is now fetched from `IAddressProvider`).

**Audit artifacts** (under `contracts/test/audit/midas/` and `specs/adapters/midas/`):

| File | Purpose | Tests |
| --- | --- | --- |
| `MidasAuditTestBase.sol` | Shared mocks: configurable data feed, issuance/redemption vault, credit manager/facade/access control, AddressProvider | — |
| `MidasDecimalMath.fuzz.t.sol` | Fuzz proofs for decimal conversion precision, monotonicity, overflow, zero-input | 7 |
| `MidasFindings.poc.t.sol` | PoCs for MID-R01, R02, R06, R09, R10, R018, R019 | 7 |
| `MidasWithdraw.invariant.t.sol` | Invariant tests for `withdraw`/`withdrawFromRedeemer` accounting | 8 |
| `MidasLiquidator.unit.t.sol` | First-ever unit tests for `MidasLiquidator` (was 0 coverage) | 8 |
| `MidasSixDecimalFlow.t.sol` | End-to-end 6-decimal issuance/redeem/request/withdraw | 2 |
| `MidasGatewayResiduals.poc.t.sol` | Residual-input PoCs — GREEN after sweeping fix (R015-017 were unreachable with real Midas; see below) | 3 |
| `MidasMathematicalProofs.md` | Formal proofs for 11 invariants | — |

**Test results:** `90 passed, 1 failed`. The single failure is an upstream test-mock regression
(`test_U_MID_G_08`), not an audit-test failure and not a production bug. See "Upstream test
regression" below.

## Verified findings (confirmed against Midas source)

### MID-R01 — Phantom overvalues when Midas settles at the saved rate
**Severity: high.** **Status: confirmed (verified against Midas source).**

`MidasRedeemer.pendingTokenOutAmount` computes the phantom value as
`amountMToken * mTokenRate_current / tokenOutRate_snapshot`, where `mTokenRate_current` is read
live from `IMidasDataFeed(mTokenDataFeed).getDataInBase18()` on every call and
`tokenOutRate_snapshot` is frozen at request time.

`RedemptionVault.sol` exposes four approval paths, each passing a different `newMTokenRate` to
`_approveRequest` (line 485-543):

| Path | `newMTokenRate` | Source line |
| --- | --- | --- |
| `safeBulkApproveRequestAtSavedRate` | `request.mTokenRate` (saved) | 332 |
| `safeBulkApproveRequest()` (no-arg) | `_getMTokenRate()` (current) | 347-348 |
| `safeBulkApproveRequest(ids, newRate)` | admin-chosen | 431 |
| `approveRequest` / `safeApproveRequest` | admin-chosen | 354, 366 |

The amount delivered to the redeemer is `(request.amountMToken * newMTokenRate) /
request.tokenOutRate` (line 508-511). When `safeBulkApproveRequestAtSavedRate` is used,
`newMTokenRate = request.mTokenRate`, so the deliverable is `amountMToken * mTokenRate_request
/ tokenOutRate` — while the Gearbox phantom reports `amountMToken * mTokenRate_current /
tokenOutRate`. If `mTokenRate_current > mTokenRate_request`, the phantom overstates the
realizable settlement by `amountMToken * (mTokenRate_current - mTokenRate_request) /
tokenOutRate`.

`safeBulkApproveRequestAtSavedRate` is gated by `onlyVaultAdmin` and calls `_approveRequest(
..., isSafe=true, safeValidateLiquidity=true)`. The `isSafe=true` branch invokes
`_requireVariationTolerance(request.mTokenRate, newMTokenRate)` (line 501), but since
`newMTokenRate = request.mTokenRate`, `priceDif = 0` and the variation check always passes.
There is no on-chain guard preventing a vault admin from settling at the saved rate after the
mToken rate has appreciated.

**PoC:** `tst_core_midas_001` (100e18 mToken request, mToken rate doubles → phantom reports
200e18, saved-rate settlement delivers only 100e18).

**Reachability:** the no-arg `safeBulkApproveRequest()` uses the current rate, which would
make the phantom exact. The risk is realized only if the vault admin uses
`safeBulkApproveRequestAtSavedRate` (or `approveRequest` with an explicit rate below the
current rate). Whether this happens in production is a deployment / operations question, but
the on-chain capability exists and is unguarded by the variation tolerance.

### MID-R02 — Cancelled request retains unbacked phantom value
**Severity: high.** **Status: confirmed (verified against Midas source).**

`RedemptionVault.rejectRequest` (line 378-386) changes `redeemRequests[requestId].status` to
`RequestStatus.Canceled` and emits `RejectRequest`. It does NOT transfer the mToken back to the
request sender and does NOT send any quote tokens. The mToken was already pulled into the vault
at request time (`_tokenTransferFromUser` in `_redeemRequest`, line 685-690) and stays there
after rejection.

`_validateRequest` (line 552-558) requires `status == Pending`, so a canceled request cannot be
re-approved through any of the four approval paths. There is no `retry`, `refund`, or `recover`
function in `RedemptionVault.sol` — the only writes to `request.status` are `Pending` (create,
line 705), `Canceled` (reject, line 383), and `Processed` (approve, line 538). A canceled
request is permanently terminal with the mToken locked in the vault.

On the Gearbox side, `MidasRedeemer.pendingTokenOutAmount` (line 106-115) returns 0 only when
`status == 1` (Processed) or `isManuallyCleared`. For `status == 2` (Canceled) with
`isManuallyCleared == false`, it continues to report `amountMToken * mTokenRate_current /
tokenOutRate`. The phantom collateral therefore retains full value despite no on-chain recovery
asset existing.

**PoC:** `tst_core_midas_002` (after `setStatus(0, 2)`, phantom still reports 100e18 while the
redeemer holds 0 quote and the mToken is locked in the vault).

### MID-R10 — `Canceled` status treated as pending (current bug, not future hypothesis)
**Severity: medium.** **Status: confirmed (verified against Midas source).**

The Midas `RequestStatus` enum (`IManageableVault.sol` line 19-23) has exactly three values:
`Pending = 0`, `Processed = 1`, `Canceled = 2`. There are no other status writes in
`RedemptionVault.sol` besides the three identified above.

`MidasRedeemer.pendingTokenOutAmount` checks only `status == 1` (Processed) and
`isManuallyCleared`; it does not check `status == 2` (Canceled) explicitly. As a result,
canceled requests are valued identically to pending requests. This is not a hypothetical
"future status" concern — it is the current behavior for the existing `Canceled` status, and it
is the same mechanism as MID-R02 viewed from the status-handling side.

**PoC:** `tst_core_midas_012` (setting status to an unknown value 99 also reports full pending
value; setting it to 2 — the actual `Canceled` value — has the same effect).

### MID-R06 — Transfer cap not enforced on destination
**Severity: medium.** **Status: confirmed.**

`MidasGateway._makeNewRedeemerForAccount` (line 303-313) enforces
`accountToPendingRedeemers[account].length() < MAX_PENDING_REDEEMERS_PER_ACCOUNT` (10) on
creation, but `transferRedeemer` (line 257-276) does not check the cap on `newAccount`.
Repeated transfers can push an account above 10 pending redeemers, unbounding the gas cost of
`withdraw` and `pendingAndClaimableTokenOutAmounts` (both iterate the pending set).

**PoC:** `tst_core_midas_007` (destination account ends at 11 pending redeemers after 10
transfers).

### MID-R09 — Transfer flag is global, not scoped to the liquidated account
**Severity: medium.** **Status: confirmed.**

`MidasLiquidator.isTransferAllowed` is a single boolean. `liquidateWithRedeemerTransfers` sets
it to `true` before calling `CreditFacade.liquidateCreditAccount` and to `false` after. While
the flag is raised for account A's liquidation, any other eligible account B can call
`MidasGateway.transferRedeemer` to move its own redeemers to a new account, even though B is
not under liquidation. The flag is not scoped to the liquidated credit account.

**PoC:** `tst_core_midas_010` (account B transfers its redeemer to account C during account
A's liquidation window).

### MID-R15 — Liquidator sweeps pre-existing residual to the next caller
**Severity: medium.** **Status: confirmed.**

`MidasLiquidator._forwardCollateral(true)` (line 67-86) transfers the *entire* current balance
of each `addCollateral` token to `msg.sender`, not just the amount originally pulled in the
pre-phase. If a prior liquidation or a direct donation left tokens on the liquidator contract,
the next liquidation's caller sweeps them.

**PoC:** `tst_core_midas_045` (a pre-existing 42e18 residual is swept to a new liquidator EOA
that only added 10e18 of its own collateral).

### MID-R018/R019 — `_sweepTokens` sweeps pre-existing gateway balances to the next caller
**Severity: medium.** **Status: confirmed (introduced by `7eaa0db`).**

The new `MidasGateway._sweepTokens` transfers the entire gateway balance of both `quoteToken`
and `mToken` to the caller, not just the delta produced by the current operation. The old
`balanceAfter - balanceBefore` accounting implicitly subtracted pre-existing balances and left
them on the gateway; the new whole-balance sweep does not.

If an attacker donates tokens to the gateway address, the next credit account that calls
`depositInstant` or `redeemInstant` sweeps the donation on top of its normal output. This is
symmetric to MID-R15 in the liquidator.

**PoCs:** `tst_core_midas_018` (donated quote swept to `depositInstant` caller),
`tst_core_midas_019` (donated mToken swept to `redeemInstant` caller).

**Impact assessment (revised after Midas source verification).** Midas
`_tokenTransferFromUser` (ManageableVault line 415-429) pulls exactly the calculated amount via
`safeTransferFrom` — the vault never under-pulls. Therefore no legitimate operation leaves a
residual on the gateway; the sweep only matters for external donations or dust from reverted
sub-calls. Practical impact is bounded: swept tokens go to a credit account (a Gearbox pool
position), not to an arbitrary EOA. The concern is silent redistribution of donations rather
than value loss.

## Findings revised after Midas source verification

### ~~MID-R015/016/017~~ — Residual input stranding (unreachable with real Midas)
**Status: not a reachable bug; defensive fix applied.**

The original concern was that the Midas vault might consume less input than the gateway
approved, leaving the unspent input stranded on the gateway. Verification against
`DepositVault._depositInstant` (line 473-509) and `RedemptionVault._redeemRequest` (line
643-712) shows that Midas always pulls exactly `amountTokenWithoutFee + feeAmount` via
`_tokenTransferFromUser`, which calls `safeTransferFrom(msg.sender, to, transferAmount)` with
the precisely calculated amount. There is no "partial fill" path in the current Midas vault
logic.

The sweeping fix in `7eaa0db` / `dc1d8b5` is therefore defensive — it does not fix a reachable
bug under the current Midas vault, but it does protect against future vault upgrades that might
introduce partial-fill behavior. The three PoCs `tst_core_midas_015/016/017` now PASS, confirming
the refund path exists. If Midas ever changes the vault to under-pull, the refund will work.

### ~~MID-R03~~ — Fees cannot inflate phantom
**Status: refuted (proven correct).**

`_redeemRequest` (line 702-709) stores `amountMToken = calcResult.amountMTokenWithoutFee` (net
after fee). The Gearbox phantom uses `request.amountMTokenIn` (the net value), so the fee is
already subtracted before the phantom valuation. Fees cannot inflate the phantom relative to
the realizable settlement.

## Proven-correct invariants (no issue)

The following are mathematically proven in `MidasMathematicalProofs.md` and backed by passing
fuzz/invariant tests. No issues found:

1. `_convertToE18` is exact for all `d <= 18`. Tests 020/021.
2. `_calculateTokenOutAmount` rounding error is strictly less than 1 quote-token unit. Test 023.
3. Pending amount is monotonically non-decreasing in `mTokenRate`. Test 022.
4. Zero input produces zero output. Test 024.
5. No overflow for realistic inputs. Test 025.
6. `depositInstantDiff` min-receive is bounded by `amount` when `rateMinRAY <= RAY`. Test 026.
7. `withdraw` transfers exactly `amount` on success and reverts atomically on over-withdraw.
   Tests 030/034/037.
8. `withdraw` removes a redeemer only when both pending and claimable are zero. Tests 030/031/032.
9. `MidasLiquidator.isTransferAllowed` is bounded to the facade call and rolls back on revert.
   Test 044.
10. Collateral forwarding conserves tokens, handles duplicate same-token calls, and cleans
    approvals. Tests 040/041/047.
11. Six-decimal quote round-trip preserves funds exactly. Tests 011/013.
12. Fees do not inflate phantom (Midas stores net amount; Gearbox reads net amount). Refutes R03.
13. `_sweepTokens` conserves tokens (no loss/creation); refund path is correct for the
    unreachable under-pull case. Tests 015-019.

## Items NOT demonstrable without deployment binding

The following candidates from `MidasSecurityResearch.md` require deployed Midas addresses,
proxy bytecode, or Gearbox market configuration to confirm or refute:

- MID-R04/MID-R13 (vault/data-feed view failures block recovery; request identity not verified)
- MID-R05 (greenlist revocation or market deregistration blocks liquidation transfer)
- MID-R07 (multi-gateway credit account may not be economically liquidatable)
- MID-R08 (core partial liquidation reverts for pending-only phantom collateral)
- MID-R11 (product-specific greenlist role compatibility)
- MID-R12 (zero `allowedMarketConfigurator` disables credit-manager registration check)
- MID-R14 (logger misconfiguration blocks delayed redemption atomically)

## Upstream test regression (not an audit finding)

`contracts/test/unit/helpers/midas/MidasGateway.unit.t.sol::test_U_MID_G_08_requestRedeem_works`
FAILS after `7eaa0db`. The upstream `MidasRedemptionVaultMock.redeemRequest` does NOT pull the
mToken from the caller (the real Midas vault does — see `_redeemRequest` line 685-690). The new
`_sweepMToken()` in `MidasRedeemer.requestRedeem` then sees the full mToken balance still on
the redeemer and sweeps it back to the account, so the assertion
`balanceOf(redeemer) == amountMToken` fails with `0 != 100e18`.

The production code is correct (the sweep is the intended defensive fix). The test mock needs
updating: either make `MidasRedemptionVaultMock.redeemRequest` pull the mToken via
`transferFrom` (faithful to upstream), or update the assertion to expect 0. The audit harness
in `MidasAuditTestBase.sol` already models the pull correctly, so the audit tests are not
affected.

## Verification

```text
forge test --skip contracts/test/unit/helpers/securitize/SecuritizeNAVFreezeF2.poc.t.sol \
  --match-path "contracts/test/**/midas/**" --summary

Result: 90 passed, 1 failed (upstream test_U_MID_G_08 regression — see above)
```

All 33 audit tests pass. Midas source verification performed against
`~/Coding/midas` at revision `90a5f246` (`RedemptionVault.sol`, `DepositVault.sol`,
`ManageableVault.sol`, `IManageableVault.sol`).
