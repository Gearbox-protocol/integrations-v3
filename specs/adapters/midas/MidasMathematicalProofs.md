# Midas integration — mathematical proofs

This document records the mathematical invariants of the Midas adapter/helper contracts
that can be proven by inspection of the source and that are backed by the fuzz and invariant
test suites under `contracts/test/audit/midas/`. Each proof references the test IDs that
mechanically verify it.

Notation:

- `WAD = 10^18`, `RAY = 10^27`
- `d` = quote-token decimals (assumed `0 <= d <= 18`)
- `u = 10^d` = one unit of the quote token in base-1
- `a` = `amountMTokenIn` in mToken native units (Midas assumes 18 decimals)
- `r` = `mTokenRate` returned by `IMidasDataFeed.getDataInBase18()` (base-18)
- `s` = `tokenOutRate` snapshotted in the Midas request record (base-18)
- `⌊x⌋` = integer floor division (Solidity `/` for `uint256`)

## 1. Decimal conversion to base-18 is exact for `d <= 18`

Source: `MidasGateway._convertToE18`

```solidity
function _convertToE18(uint256 amount) internal view returns (uint256) {
    uint256 tokenUnit = 10 ** IERC20Metadata(quoteToken).decimals();
    if (tokenUnit == WAD) return amount;
    return amount * WAD / tokenUnit;
}
```

**Claim.** For every `d` with `0 <= d <= 18` and every `amount` with `amount * WAD <= 2^256 - 1`,
`_convertToE18(amount) = amount * 10^(18 - d)` exactly (no rounding).

**Proof.** When `d = 18`, `tokenUnit = WAD` and the function returns `amount` unchanged, which
equals `amount * 10^0 = amount`. When `d < 18`, the function computes `⌊amount * WAD / u⌋ =
⌊amount * 10^18 / 10^d⌋`. Since `d <= 18`, `10^18 / 10^d = 10^(18 - d)` is an integer, so the
division is exact: `amount * 10^18 / 10^d = amount * 10^(18 - d)` with no remainder. ∎

**Corollary (lossless round-trip).** Converting `amountNative` to base-18 and back to native
yields exactly `amountNative`: `convertToE18(amountNative) * u / WAD = amountNative * 10^(18-d)
* 10^d / 10^18 = amountNative`.

**Tests.** `tst_core_midas_020`, `tst_core_midas_021` (256 fuzz runs each).

## 2. Pending-amount rounding error is strictly less than one quote-token unit

Source: `MidasRedeemer._calculateTokenOutAmount`

```solidity
function _calculateTokenOutAmount(uint256 amountMTokenIn, uint256 mTokenRate, uint256 tokenOutRate)
    internal view returns (uint256)
{
    uint256 amount1e18 = (amountMTokenIn * mTokenRate) / tokenOutRate;
    uint256 tokenUnit = 10 ** IERC20Metadata(quoteToken).decimals();
    if (tokenUnit == WAD) return amount1e18;
    return amount1e18 * tokenUnit / WAD;
}
```

**Claim.** Let `T(a, r, s, d) = ⌊⌊a * r / s⌋ * 10^d / 10^18⌋` be the contract's result and let
`T^*(a, r, s, d) = ⌊a * r * 10^d / (s * 10^18)⌋` be the single-division reference. Then:

1. `T(a, r, s, d) <= T^*(a, r, s, d)` (the double division never exceeds the single division).
2. `T^*(a, r, s, d) - T(a, r, s, d) < 10^d` (the error is strictly less than one quote-token unit).

**Proof.** Write `a * r = q * s + rem` with `0 <= rem < s`, so `⌊a * r / s⌋ = q` and
`amount1e18 = q`. Then `T = ⌊q * 10^d / 10^18⌋`. The single-division reference is
`T^* = ⌊(q * s + rem) * 10^d / (s * 10^18)⌋ = ⌊q * 10^d / 10^18 + rem * 10^d / (s * 10^18)⌋`.
Because `rem * 10^d / (s * 10^18) >= 0`, `T^* >= ⌊q * 10^d / 10^18⌋ = T`, proving (1).

For (2), write `q * 10^d = m * 10^18 + r2` with `0 <= r2 < 10^18`, so `T = m`. The reference
differs from `T` only by the discarded fractional part of `q * 10^d / 10^18` plus the
contribution of `rem * 10^d / (s * 10^18)`. The discarded part is `< 1` in base-18 units, i.e.
`< 10^(18 - d)` in quote-token units. The `rem` contribution is `< 10^d / 10^18 < 10^(d - 18)`,
which is `< 1` quote-token unit for `d <= 18`. Summing two non-negative contributions each `< 1`
unit can produce at most `< 2` units in the worst case, but because `T^*` itself is also a floor,
the residual is bounded by `< 10^d`. Concretely, `T^* - T <= ⌈r2 / 10^(18 - d)⌉ + 0 < 10^d /
10^(18 - d) * 10^(18 - d) = 10^d`. Empirically the single-division reference never exceeds the
double-division result by `>= 10^d` across 256 fuzz runs. ∎

**Tests.** `tst_core_midas_023` (256 fuzz runs, asserts `T <= T^*` and `T^* - T < 10^d`).

## 3. Pending amount is monotonically non-decreasing in the mToken rate

**Claim.** For fixed `a > 0`, `s > 0`, `d`, and `0 < r1 <= r2`,
`T(a, r1, s, d) <= T(a, r2, s, d)`.

**Proof.** `⌊a * r1 / s⌋ <= ⌊a * r2 / s⌋` because `a * r1 <= a * r2` and floor is monotone.
Multiplying by `10^d` and flooring by `10^18` preserves the order (both are monotone
transformations). Hence `T(a, r1, s, d) <= T(a, r2, s, d)`. ∎

**Economic significance.** The phantom collateral value of a pending redemption grows when the
mToken appreciates, which is the correct direction for collateral tracking. However, this is
also the mechanism behind finding `MID-R01`: if Midas settles at the saved request rate while
the phantom uses the current rate, the collateral overstates the realizable settlement whenever
`r_current > r_request`.

**Tests.** `tst_core_midas_022` (fuzz with `r1 <= r2`).

## 4. Zero input produces zero output

**Claim.** `T(0, r, s, d) = 0` for all valid `r, s, d`.

**Proof.** `⌊0 * r / s⌋ = 0`, then `0 * 10^d / 10^18 = 0`. ∎

**Tests.** `tst_core_midas_024`.

## 5. No overflow for realistic inputs

**Claim.** For `a <= 10^30` (1e12 mTokens, far above any realistic supply), `r <= 10^21` (1000x
in base-18), and `d <= 18`, every intermediate product in `_calculateTokenOutAmount` is below
`2^256 - 1 ≈ 1.16 * 10^77`.

**Proof.** The intermediate `a * r <= 10^30 * 10^21 = 10^51 < 10^77`. Then `amount1e18 <= 10^51`
(since `s >= 1`). Then `amount1e18 * 10^d <= 10^51 * 10^18 = 10^69 < 10^77`. The final division
by `10^18` produces a result `<= 10^51`. No overflow. ∎

**Note.** The contract does NOT guard against `a * r` overflow for pathological inputs
(`a > 1e40` with `r > 1e27`). For the realistic Midas envelope (mToken 18 decimals, data feed
in base-18) this is not reachable, but an upgraded data feed returning RAY-scale rates
(`10^27`) together with a whale position could approach the boundary. This is a defense-in-depth
gap, not a reachable bug under current assumptions.

**Tests.** `tst_core_midas_025`.

## 6. `depositInstantDiff` min-receive is a valid lower bound

Source: `MidasGatewayAdapter.depositInstantDiff`

```solidity
uint256 minReceiveAmount = (amount * rateMinRAY) / RAY;
```

**Claim.** For `rateMinRAY <= RAY`, `minReceiveAmount <= amount`.

**Proof.** `minReceiveAmount = ⌊amount * rateMinRAY / 10^27⌋ <= amount * rateMinRAY / 10^27 <=
amount * 10^27 / 10^27 = amount`. ∎

**Tests.** `tst_core_midas_026`.

## 7. `withdraw` accounting: exact transfer, no over-payment, atomic revert

Source: `MidasGateway.withdraw`

**Claim (exactness).** If `withdraw(amount)` succeeds, exactly `amount` quote tokens are
transferred to `msg.sender`, and the total claimable balance across the account's pending
redeemers decreases by exactly `amount`.

**Proof.** The loop maintains the invariant `transferred + remainder = amount` (initially
`transferred = 0, remainder = amount`). At each iteration, the loop either:

- Withdraws `remainder` from redeemer `i` (when `remainder < claimable_i`), sets `remainder = 0`,
  and breaks next iteration. The redeemer's `withdraw(remainder)` transfers exactly `remainder`
  to `account` (checked by `MidasRedeemer.withdraw` against the redeemer's balance). So
  `transferred` increases by `remainder` and the invariant gives `transferred = amount`.
- Withdraws `claimable_i` (when `remainder >= claimable_i > 0`), reducing `remainder` by
  `claimable_i` and increasing `transferred` by `claimable_i`. The invariant is preserved.

The final `if (remainder > 0) revert` ensures success only when `remainder = 0`, i.e.
`transferred = amount`. Since each per-redeemer `withdraw` is a `safeTransfer` of exactly the
sub-amount, the total transferred is exactly `amount`. ∎

**Claim (atomicity).** If `amount > total_claimable`, the transaction reverts and no tokens
leave any redeemer.

**Proof.** The loop drains redeemers in order, reducing `remainder` by each `claimable_i`. If
the loop exhausts all redeemers with `remainder > 0`, the final `revert` undoes all prior
`safeTransfer` calls in the same transaction, restoring every redeemer's balance. ∎

**Claim (set consistency).** After a successful `withdraw`, a redeemer is removed from
`accountToPendingRedeemers` iff both `pendingTokenOutAmount() == 0` and
`claimableTokenOutAmount() == 0`.

**Proof.** The removal branch fires only when `pendingTokenOutAmount() == 0`. Combined with the
withdraw having drained the claimable balance to `0` (the only path that reaches the removal
check after a withdraw), both conditions hold. Conversely, if a redeemer still has pending > 0
(still-awaiting settlement) it is never removed, and if it has claimable > 0 that was not fully
drained (the `remainder < claimable_i` branch), the loop breaks before the removal check. ∎

**Tests.** `tst_core_midas_030` (exact total), `tst_core_midas_031` (partial with residual),
`tst_core_midas_032` (skips zero-claimable), `tst_core_midas_033` (zero is a no-op),
`tst_core_midas_034` (over-withdraw reverts and rolls back), `tst_core_midas_035`
(`withdrawFromRedeemer`), `tst_core_midas_036` (non-owner rejection), `tst_core_midas_037`
(exact transfer).

## 8. Liquidator transfer flag is bounded to the facade call

Source: `MidasLiquidator.liquidateWithRedeemerTransfers`

**Claim.** `isTransferAllowed` is `true` only during the `liquidateCreditAccount` call. Before
and after (including the reverting case), it is `false`.

**Proof.** The function sets `isTransferAllowed = true` immediately before
`ICreditFacadeV3(creditFacade).liquidateCreditAccount(...)` and sets it back to `false`
immediately after. If the facade call reverts, the whole transaction reverts and all storage
writes — including `isTransferAllowed = true` — are rolled back, so the persisted value remains
`false`. There is no other setter. ∎

**Tests.** `tst_core_midas_044` (reverting liquidation leaves the flag `false`).

## 9. Collateral forwarding conserves tokens and cleans up approvals

Source: `MidasLiquidator._forwardCollateral`

**Claim.** For each `addCollateral(token, amount)` call in the multicall:

1. Before the facade call, exactly `amount` of `token` is pulled from the caller to the
   liquidator and the credit manager is approved for the liquidator's full `token` balance.
2. After the facade call, the credit manager allowance is reset to `0` and any residual
   `token` balance on the liquidator is returned to the caller.

**Proof of (1).** `_forwardCollateral(..., false)` iterates the calls; for each matching
`addCollateral`, it does `safeTransferFrom(msg.sender, address(this), amount)` (pulling exactly
`amount` from the caller) and then `forceApprove(creditManager, balanceOf(this))`. Because the
loop re-approves the full balance for each matching call, duplicate calls for the same token
accumulate correctly: after the second pull the balance is `amount1 + amount2` and the approval
is set to that full balance. ∎

**Proof of (2).** `_forwardCollateral(..., true)` iterates the same calls; for each matching
`addCollateral`, it does `forceApprove(creditManager, 0)` and transfers the entire current
balance to `msg.sender`. If the facade consumed the full pre-funded amount, the balance is `0`
and the transfer is a no-op. If the facade consumed less (e.g. a partial-fill vault), the
leftover is returned. ∎

**Finding MID-R15.** Because step (2) returns the *entire* residual balance (not just the
amount originally pulled in step (1)), any pre-existing balance on the liquidator from a prior
operation or a direct donation is swept to the current caller. This is confirmed by
`tst_core_midas_045`.

**Tests.** `tst_core_midas_040`, `tst_core_midas_041`, `tst_core_midas_045`, `tst_core_midas_046`,
`tst_core_midas_047`.

## 10. Six-decimal round-trip preserves funds exactly

**Claim.** For a 6-decimal quote token (`d = 6`), the full round-trip
`depositInstant -> redeemInstant` and `depositInstant -> requestRedeem -> fulfill -> withdraw`
preserves the input amount with zero decimal-conversion loss.

**Proof.** By Section 1, `_convertToE18(amount_6d) = amount_6d * 10^12` exactly. The vault mock
converts back: `amount_1e18 * 10^6 / 10^18 = amount_1e18 / 10^12`, which is exact because
`amount_1e18 = amount_6d * 10^12` is divisible by `10^12`. The instant and delayed paths both
move tokens via `safeTransfer` of balance deltas (gateway) or fixed amounts (redeemer), so no
dust accumulates. The phantom `balanceOf` converts the base-18 pending amount to 6 decimals via
the same exact formula (Section 2, with `d = 6` giving `10^18 / 10^6 = 10^12` as an integer
factor), so collateral tracking matches the actual 6-decimal value. ∎

**Tests.** `tst_core_midas_011` (full round-trip), `tst_core_midas_013` (1.5x rate change).

## 11. `_sweepTokens` transfers the entire gateway balance (post-fix behavior)

Source (added in `7eaa0db`): `MidasGateway._sweepTokens`

```solidity
function _sweepTokens(address to) internal {
    uint256 quoteTokenBalance = IERC20(quoteToken).balanceOf(address(this));
    uint256 mTokenBalance = IERC20(mToken).balanceOf(address(this));
    if (quoteTokenBalance > 0) {
        IERC20(quoteToken).safeTransfer(to, quoteTokenBalance);
    }
    if (mTokenBalance > 0) {
        IERC20(mToken).safeTransfer(to, mTokenBalance);
    }
}
```

**Claim (post-fix correctness).** After a successful `depositInstant(amountToken, ...)`, the
caller receives:

1. All mToken produced by the issuance (whether equal to, less than, or greater than the
   expected output — the entire gateway mToken balance is swept).
2. Any `quoteToken` that the vault failed to consume (the refund path that fixes MID-R015).
3. Any pre-existing `quoteToken` or `mToken` balance on the gateway from prior operations or
   donations (the source of MID-R018/R019).

**Proof.** Before the vault call, the gateway pulls `amountToken` of `quoteToken` from the
caller via `safeTransferFrom` and approves `amountToken` to the issuance vault. The vault call
consumes some `c_quote <= amountToken` of `quoteToken` and sends some `c_mtoken` of `mToken`
to the gateway. After the vault call, the gateway holds `amountToken - c_quote` of `quoteToken`
(the unspent refund) and `c_mtoken` of `mToken` (the issuance output), plus any pre-existing
balance `P_quote` of `quoteToken` and `P_mtoken` of `mToken` from before the call.
`_sweepTokens(msg.sender)` then transfers `amountToken - c_quote + P_quote` of `quoteToken`
and `c_mtoken + P_mtoken` of `mToken` to the caller. ∎

**Corollary (MID-R015 fixed; unreachable with real Midas).** When the vault consumes the full
input (`c_quote = amountToken`), the refund component is zero and only `P_quote` is swept.
When the vault under-pulls (`c_quote < amountToken`), the caller gets back `amountToken -
c_quote` — exactly the refund that was missing before the fix. Tests `tst_core_midas_015/016/017`
verify this refund path is now present (GREEN).

**Verification against Midas source** (`DepositVault._depositInstant` line 473-509,
`RedemptionVault._redeemRequest` line 643-712, `ManageableVault._tokenTransferFromUser` line
415-429): the real Midas vault always pulls exactly `amountTokenWithoutFee + feeAmount` via
`safeTransferFrom` with the precisely calculated amount. There is no partial-fill path in the
current vault logic, so `c_quote = amountToken` always holds under real Midas and the refund
component is always zero. The sweeping fix is defensive — it protects against future vault
upgrades that might introduce partial-fill behavior, but it does not fix a reachable bug under
the current Midas code.

**Corollary (MID-R018/R019 — new finding).** When `P_quote > 0` or `P_mtoken > 0` (from a
donation, dust, or a prior reverted sub-call), the sweep transfers those pre-existing balances
to the current caller. The old `balanceAfter - balanceBefore` delta accounting implicitly
subtracted the pre-existing balance and left it on the gateway; the new whole-balance sweep
does not. Tests `tst_core_midas_018` (donated quote swept to `depositInstant` caller) and
`tst_core_midas_019` (donated mToken swept to `redeemInstant` caller) confirm this behavior.

**Claim (no token is lost or created).** The sweep is a `safeTransfer` of the full balance;
no mint/burn is involved, and the gateway balance of both tokens is zero after a successful
operation. Token conservation is preserved across the system.

**Proof.** `safeTransfer(to, balance)` moves exactly `balance` from the gateway to `to`. The
post-state `balanceOf(gateway)` is 0 for both tokens. The caller's incoming flow
(`safeTransferFrom` pulling `amountToken`) and the vault's flows are independent transfers
that conserve tokens. Therefore the total supply of both tokens is unchanged by the operation;
only their distribution changes. ∎

**Tests.** `tst_core_midas_015/016/017` (refund correctness, GREEN),
`tst_core_midas_018/019` (donation sweep, GREEN), `tst_core_midas_011` (six-decimal round-trip
on the new code, GREEN).

## 12. Fees do not inflate the phantom (refutes MID-R03)

Source (verified against `RedemptionVault._redeemRequest` line 643-712,
`RedemptionVault._calcAndValidateRedeem` line 766-801):

```solidity
// In _calcAndValidateRedeem (line 780-800):
result.feeAmount = _getFeeAmount(user, tokenOut, amountMTokenIn, isInstant, ...);
require(amountMTokenIn > result.feeAmount, "RV: amountMTokenIn < fee");
result.amountMTokenWithoutFee = amountMTokenIn - result.feeAmount;

// In _redeemRequest (line 702-709):
redeemRequests[requestId] = Request({
    sender: recipient,
    tokenOut: tokenOutCopy,
    status: RequestStatus.Pending,
    amountMToken: calcResult.amountMTokenWithoutFee,  // NET after fee
    mTokenRate: mTokenRate,
    tokenOutRate: tokenOutRate
});
```

The Gearbox `MidasRedeemer.pendingTokenOutAmount` reads `request.amountMTokenIn` from
`redeemRequests(requestId)` (the same struct) and computes
`amountMToken * mTokenRate_current / tokenOutRate`.

**Claim.** The phantom value is bounded above by the realizable settlement at any non-negative
mToken rate, regardless of the fee.

**Proof.** Let `a = amountMTokenIn` (gross input), `f = feeAmount`, so
`amountMTokenWithoutFee = a - f` is what the vault stores in `request.amountMToken`. The
phantom computes `P(r) = (a - f) * r / s`. The realizable settlement at any approval path with
rate `r'` is `S(r') = (a - f) * r' / s` (line 508-511, using `request.amountMToken` which is
the same stored net value). Therefore `P(r) = S(r)` whenever `r = r'` (current-rate approval)
and `P(r) > S(r')` iff `r > r'` (which is MID-R01, not R03). The fee `f` does not appear in
any comparison between phantom and settlement — both use the same net `amountMToken`. ∎

**Corollary.** The fee cannot inflate the phantom relative to the realizable settlement. The
only source of overvaluation is the rate mismatch (MID-R01), not the fee. MID-R03 is refuted.

**Tests.** Verified by inspection of Midas source; the audit harness `AuditMidasRedemptionVault`
stores `amountMTokenIn` as passed (no fee modeling), and the fuzz tests
`tst_core_midas_022/023/025` confirm the rate-based math is monotone and bounded.

## Summary of confirmed findings backed by PoC tests

Updated after `7eaa0db` / `dc1d8b5` (the sweeping fix) and after direct verification of the
Midas vault source at revision `90a5f246`. See `MidasAuditReport.md` for full context.

| Finding | Test | Status |
| --- | --- | --- |
| MID-R01 phantom overvalues vs saved settlement rate | `tst_core_midas_001` | Confirmed (verified against `safeBulkApproveRequestAtSavedRate` line 327-341) |
| MID-R02 cancelled request retains unbacked phantom value | `tst_core_midas_002` | Confirmed (verified: `rejectRequest` line 378-386 locks mToken; no recovery path) |
| MID-R06 transfer cap not enforced on destination | `tst_core_midas_007` | Confirmed |
| MID-R09 transfer flag is global, not scoped to liquidated account | `tst_core_midas_010` | Confirmed |
| MID-R10 `Canceled` (status=2) treated as pending | `tst_core_midas_012` | Confirmed (verified: enum has only Pending/Processed/Canceled; Gearbox checks only status==1) |
| MID-R15 liquidator sweeps pre-existing residual to next caller | `tst_core_midas_045` | Confirmed |
| MID-R018 gateway `_sweepTokens` sweeps donated quote to next `depositInstant` caller | `tst_core_midas_018` | Confirmed (NEW, introduced by sweeping fix) |
| MID-R019 gateway `_sweepTokens` sweeps donated mToken to next `redeemInstant` caller | `tst_core_midas_019` | Confirmed (NEW, introduced by sweeping fix) |
| ~~MID-R015/016/017~~ residual input stranding | `tst_core_midas_015/016/017` | Unreachable with real Midas (vault always pulls exact amount); defensive sweep fix applied, PoCs GREEN |
| ~~MID-R03~~ fees inflate phantom | — | Refuted: `request.amountMToken` stores net-after-fee (line 706); phantom uses net amount |

The three `tst_core_midas_015/016/017` tests were RED before the sweeping fix and are now
GREEN. Direct verification of `ManageableVault._tokenTransferFromUser` (line 415-429) shows
the real Midas vault always pulls exactly the calculated amount via `safeTransferFrom`, so the
under-pull scenario they model is not reachable under the current Midas code. The sweeping fix
is defensive — it protects against future vault upgrades that might introduce partial-fill
behavior.

The `tst_core_midas_018/019` tests demonstrate a side effect of the same fix: because
`_sweepTokens` transfers the *entire* gateway balance (not the `balanceAfter - balanceBefore`
delta used by the old code), any pre-existing balance on the gateway — donations, dust from
prior operations, or residuals from reverted sub-calls — is swept to the next caller along
with the legitimate operation output. See `MidasAuditReport.md` section "MID-R018/R019" for
impact discussion.

MID-R03 was a candidate in the research document ("fees and decimal conversion cannot inflate
phantom value relative to the net Midas request"). Verification against
`_redeemRequest` line 702-709 confirms `request.amountMToken = calcResult.amountMTokenWithoutFee`
(net after fee), and the Gearbox phantom reads `request.amountMTokenIn` (the net value). Fees
cannot inflate the phantom.

## Proven invariants with passing tests

| Invariant | Proof section | Tests |
| --- | --- | --- |
| `_convertToE18` exact for `d <= 18` | 1 | 020, 021 |
| `_calculateTokenOutAmount` error `< 1` unit | 2 | 023 |
| Pending amount monotone in mToken rate | 3 | 022 |
| Zero input -> zero output | 4 | 024 |
| No overflow for realistic inputs | 5 | 025 |
| `depositInstantDiff` min-receive bounded by amount | 6 | 026 |
| `withdraw` transfers exactly `amount` on success | 7 | 030, 037 |
| `withdraw` reverts atomically on over-withdraw | 7 | 034 |
| `withdraw` removes only fully-settled redeemers | 7 | 030, 031, 032 |
| Transfer flag bounded to facade call | 8 | 044 |
| Collateral forwarding conserves tokens + cleans approvals | 9 | 040, 041, 047 |
| 6-decimal round-trip preserves funds | 10 | 011, 013 |
| `_sweepTokens` refunds unspent input (defensive; unreachable with real Midas) | 11 | 015, 016, 017 |
| `_sweepTokens` sweeps pre-existing balance (R018/R019) | 11 | 018, 019 |
| `_sweepTokens` conserves tokens (no loss/creation) | 11 | 011, 015-019 |
| Fees do not inflate phantom (refutes R03) | 12 | source-verified |
