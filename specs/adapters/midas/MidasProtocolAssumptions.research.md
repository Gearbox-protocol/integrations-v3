# Midas protocol assumptions — research

Cross-check of the assumptions made by the Gearbox Midas integration
(`MidasGateway`, `MidasRedeemer`, `MidasRedemptionVaultPhantomToken`,
`MidasGatewayAdapter`, `MidasLiquidator`) and its spec
(`MidasIntegration.spec.md`) against the actual Midas protocol sources.

- Midas sources: [midas-apps/contracts](https://github.com/midas-apps/contracts),
  commit `50ba423` (2026-07-14), `contracts/` directory.
- Gearbox side: branch `midas-rwa`, commit `114acb7`.
- Key Midas files reviewed: `RedemptionVault.sol`, `DepositVault.sol`,
  `RedemptionVaultWithSwapper.sol`, `abstract/ManageableVault.sol`,
  `access/{Pausable,Greenlistable,Blacklistable,MidasAccessControl}.sol`,
  `feeds/DataFeed.sol`, `mToken.sol`.

Verdict up front: the integration's *mechanical* assumptions (ABI, struct
layout, settlement address, request statuses) are correct. The *behavioral*
assumptions are happy-path: nearly every Midas flow has admin- or
market-triggered modes in which funds do not arrive, calls revert, or
valuations diverge — and neither the spec, the code, nor (especially) the unit
test mocks model them.

---

## 1. Assumptions verified as CORRECT

| # | Our assumption | Midas reality (file:line @ 50ba423) |
|---|---|---|
| C-1 | Settlement of a delayed redemption arrives as `tokenOut` on the request `sender` address (our redeemer clone) | `RedemptionVault.sol:525-531` — `_approveRequest` does `_tokenTransferFromTo(request.tokenOut, requestRedeemer, request.sender, ...)` |
| C-2 | `redeemRequests(id)` returns `(sender, tokenOut, status, amountMToken, mTokenRate, tokenOutRate)` | `interfaces/IRedemptionVault.sol:15-22` — struct field order matches our `IMidasRedemptionVault` destructuring |
| C-3 | Statuses: 0 = Pending, 1 = Processed, 2 = Canceled | `RequestStatus` enum; `_validateRequest` requires Pending |
| C-4 | `tokenOutRate` is frozen at request time; settlement = `amountMToken * rate / tokenOutRate`, truncated to token decimals | `RedemptionVault.sol:702-709`, `508-511` |
| C-5 | `depositInstant(tokenIn, amountToken, minReceiveAmount, referrerId)` takes `amountToken` in base-18; vault pulls the converted native amount | `DepositVault.sol` `_calcAndValidateDeposit` + `_tokenTransferFromUser` (`ManageableVault.sol:415-429`) |
| C-6 | `redeemInstant` `minReceiveAmount` is compared in base-18 | `RedemptionVault.sol:606-614` |
| C-7 | Fees don't break our transfers: gateway uses balance-diff on both instant flows; request stores the **net** amount which our valuation reads | `RedemptionVault.sol:780-801` (`amountMTokenWithoutFee`), request struct stores net |
| C-8 | Deposit consumes the full approved amount for ≤18-decimals tokens (no dust left on gateway): fee is truncated to token decimals, so `amount`, `fee`, `amount - fee` all convert cleanly | `DepositVault.sol:679-683` (`_truncate` on fee), rounding `require` in `ManageableVault.sol:423-426`. Answers the `Q:` comment in `MidasGateway.depositInstant`. **Exception:** tokens with >18 decimals would strand dust (our `_convertToE18` truncates) — currently exotic |

---

## 2. Overly optimistic assumptions (ranked by severity)

### A-1. HIGH — Stale/unhealthy data feed reverts, freezing the entire credit account (including liquidation)

- **We assume:** `mTokenDataFeed.getDataInBase18()` always returns a rate
  (spec: "Oracle/data feed trust", listed as a *pricing* concern only).
- **Reality:** `feeds/DataFeed.sol:156-174` — `getDataInBase18()` **reverts**
  with `"DF: feed is unhealthy"` when `block.timestamp - updatedAt >
  healthyDiff`, or the answer is outside `[minExpectedAnswer,
  maxExpectedAnswer]`, and `"DF: feed is deprecated"` when `answer <= 0`.
  `healthyDiff` / bounds are admin-settable at any time.
- **Impact chain:** `MidasRedeemer.pendingTokenOutAmount()` (line 131) →
  `MidasGateway.pendingAndClaimableTokenOutAmounts()` →
  `MidasRedemptionVaultPhantomToken.balanceOf()` → **reverts**. Since the
  phantom token is enabled collateral, every collateral evaluation of the
  credit account reverts: no multicall, no debt repayment, **no
  liquidation** while the feed is stale or the price is outside admin bounds.
  Exactly when the mToken price crashes through `minExpectedAnswer` —
  i.e. when liquidation is most needed — accounts holding the phantom token
  become un-liquidatable.
- **Note:** the same revert hits `requestRedeem` (`RedemptionVault.sol:683`)
  and both instant flows, but there a revert is merely an inconvenience; on
  `balanceOf` it is a DoS on risk management.
- **Recommendation:** decide explicitly: catch the revert in
  `pendingTokenOutAmount` and fall back to the request-time
  `mTokenRate` (needs team sign-off — NO-FALLBACKS rule), or accept and
  document as TA with monitoring. Add tests that assert the *chosen*
  behavior under a reverting feed.

### A-2. HIGH — `rejectRequest` does not return mTokens; a canceled request keeps full collateral value indefinitely

- **We assume (spec):** cancellation is an "accident" remedied by
  `clearCancelledRequest` ("relying on external party to supply funds").
- **Reality:** `RedemptionVault.sol:378-386` — reject only flips status to
  `Canceled`. The mTokens transferred at request time
  (`RedemptionVault.sol:685-690`) stay with the vault; nothing flows back.
  There is **no obligation and no incentive** for anyone to call our
  `clearCancelledRequest` (they must donate ≥ the request-rate value).
- **Impact:** `MidasRedeemer.pendingTokenOutAmount` returns 0 only for
  `status == 1` or `isManuallyCleared` (`MidasRedeemer.sol:128`). A canceled
  request therefore keeps counting as pending collateral at **current feed
  rate**, backed by nothing. The borrower can neither withdraw the value nor
  can a liquidator realize it (`transferRedeemer` moves an empty shell).
  Phantom collateral is overstated until (if ever) someone clears it.
- **Recommendation:** make this Trust Assumption #1 in the spec, agree with
  Midas on an operational SLA for clearing rejected requests, and add tests:
  reject → valuation stays (documenting the choice), reject → clear →
  valuation moves to claimable, liquidation of an account holding a
  canceled-but-not-cleared redeemer.

### A-3. MEDIUM — Admin sets the settlement rate; our pending valuation uses the live feed

- **We assume (spec):** "Pending valuation uses the current mToken data feed
  rate, so collateral tracks live mToken pricing."
- **Reality:** settlement uses **admin-supplied** `newMTokenRate`:
  unbounded for `approveRequest` (`RedemptionVault.sol:354-361`), bounded by
  `variationTolerance` (relative to the *request-time* rate, not the current
  one) for `safeApproveRequest`; `safeBulkApproveRequestAtSavedRate`
  settles at the **request-time** rate (`RedemptionVault.sol:327-341`).
  Result is truncated to token decimals.
- **Impact:** realized proceeds can differ from our live-feed valuation by
  the full tolerance band (or arbitrarily, for non-safe approve). The phantom
  balance steps discontinuously at approval. HF computed a block before
  settlement can be wrong afterwards.
- **Recommendation:** quantify: fuzz test over (request rate, live rate,
  admin rate within/without tolerance) asserting bounded valuation error;
  document max tolerated `variationTolerance` per market in risk params.

### A-4. MEDIUM — The mToken itself is pausable and blacklist-gated on every transfer

- **We assume:** mToken behaves as a plain ERC-20.
- **Reality:** `mToken.sol` extends `ERC20PausableUpgradeable`;
  `_beforeTokenTransfer` also requires both `from` and `to` to be
  non-blacklisted. Pause/blacklist are Midas-admin actions.
- **Impact:** while paused (or if the gateway / a redeemer clone / a CA is
  blacklisted), *our own* internal moves revert: `depositInstant`'s return
  transfer, `requestRedeem`'s CA→redeemer transfer. mToken held as regular
  Gearbox collateral also becomes untransferable (affects liquidation of the
  *mToken* position, independent of the phantom token).
- **Recommendation:** trust assumption + adverse-mode tests with a
  pausable/blacklistable mToken mock (current `ERC20Mock` can model neither).

### A-5. MEDIUM — Permissioned deployments depend on the gateway holding `GREENLIST_OPERATOR_ROLE`; greenlist can also be turned ON later

- **We assume (spec):** "gateway temporarily grants and revokes
  GREENLISTED_ROLE" — presented as a mechanical detail.
- **Reality:** `MidasAccessControl.sol:74` — the admin of `GREENLISTED_ROLE`
  is `GREENLIST_OPERATOR_ROLE`. Our `_grantGreenlistIfRequired` works only
  while Midas keeps our gateway in that operator role; revocation is
  unilateral and instant. Separately, `Greenlistable.sol:30` checks the
  greenlist **only if `greenlistEnabled`**, and `setGreenlistEnable` can flip
  it on at any time.
- **Impact:** two bricking scenarios: (a) operator role revoked → every
  `grantRole` call reverts → all three flows dead on a permissioned
  deployment; (b) gateway deployed with `accessControl = address(0)`
  (immutable!) against a "permissionless" vault, Midas later enables the
  greenlist → gateway has no code path to greenlist itself, integration
  dead. Settled redeemers can still be withdrawn (withdraw path doesn't
  touch Midas), pending ones still settle (push from `requestRedeemer`).
- **Recommendation:** document both as TAs; consider always wiring
  `accessControl` when the vault supports it, regardless of current
  `greenlistEnabled`; add tests for grant-revert propagation.

### A-6. MEDIUM — Every flow has admin/market failure modes our tests never exercise

All of the following revert paths exist on the *current* vaults and are
invisible in our mocks:

| Midas mechanism | Where | What reverts for us |
|---|---|---|
| Global pause + per-function pause | `access/Pausable.sol:33-37`, selectors in each vault | any of `depositInstant` / `redeemInstant` / `redeemRequest` individually |
| Instant daily limit (in mToken, per day) | `ManageableVault.sol:505-512` | both instant flows, unpredictably for the *n*-th user of the day |
| Per-token allowance, decremented per op — **also at `_approveRequest`** | `ManageableVault.sol:519-528`, `RedemptionVault.sol:534` | instant flows; and Midas-side settlement itself can be blocked → "pending forever" |
| `minAmount` / `minFiatRedeemAmount`, `minMTokenAmountForFirstDeposit`, `maxSupplyCap` | `RedemptionVault.sol:775-778`, `DepositVault.sol` | small `redeemRequestDiff` leftovers; first deposit; deposits near cap |
| `removePaymentToken` | `ManageableVault.sol:233-237` | new requests for that token; also blocks approval of *existing* requests (allowance of deleted config = 0) until re-added |
| Sanctions list (external oracle) on `msg.sender` | `WithSanctionsList`, `_validateUserAccess` (`ManageableVault.sol:585-591`) | everything, if gateway/redeemer ever flagged |
| Rounding guard `"MV: invalid rounding"` | `ManageableVault.sol:423-426` | any base-18 amount that doesn't divide cleanly into native decimals (our conversions are clean today; keep it that way under fuzz) |
| `withdrawToken` — admin can pull any token from the vault | `ManageableVault.sol:189-197` | pure custody trust; instant liquidity is discretionary |

**Recommendation:** these are exactly the "something doesn't arrive /
doesn't work" cases. Model each toggle in one realistic shared mock and
assert revert propagation through adapter → gateway (and *no state
corruption*: no pending-set entry created, no tokens stranded).

### A-7. LOW/MEDIUM — Vault variants differ; the spec assumes the base `RedemptionVault`

- **Reality:** production deployments use per-product variants —
  `RedemptionVaultWithSwapper` (instant redemption routes through a second
  product's vault via a `liquidityProvider`, burns vs transfers differ),
  `WithBUIDL`, `WithUSTB`, `WithAave`, `WithMorpho`. The request flow is
  inherited from the base contract, but instant-flow liquidity, fees and
  failure modes differ per variant. All vaults sit behind upgradeable
  proxies (`initializer` + `__gap`) — behavior can change post-deployment.
- **Recommendation:** the deployment config must pin (variant, chain,
  product) per gateway; fork tests against the *actual* proxy addresses are
  the only durable protection against upgrades and variant drift.

### A-8. LOW — Request IDs start at 0; default `requestId == 0` aliases the first real request

- **Reality:** `RedemptionVault.sol:699-700` — `requestId =
  currentRequestId.current(); increment()`; the first request is id **0**.
- **Impact:** a `MidasRedeemer` that never called `requestRedeem` (the
  master copy; clones mid-tx) has `requestId == 0` by default and would read
  *someone else's* request 0. Reachable surface is tiny (master is in no
  set; `clearCancelledRequest` is permissionless but only lets a griefer
  donate funds into the master where they're stuck). Our unit-test vault
  mock starts ids at **1**, masking the whole class.
- **Recommendation:** align mocks to 0-based ids; consider asserting
  `alreadyRedeemed` in `pendingTokenOutAmount`/`clearCancelledRequest`.

---

## 3. Mock divergences from reality (unit tests)

Current mocks (three separate copies in `MidasGateway.unit.t.sol`,
`MidasRedeemer.unit.t.sol`, `MidasGatewayAdapter.unit.t.sol`):

| Mock behavior | Real behavior |
|---|---|
| No fees anywhere | fee in mToken/tokenIn on every flow, waivable per address, changeable up to 100% |
| Rates pinned to 1e18, feed never reverts | admin-set settlement rate; feed reverts on stale/out-of-bounds |
| Request ids from 1 | ids from 0 |
| Request stores gross amount | stores **net** (post-fee) amount |
| `redeemInstant`/`depositInstant` pay a preset amount, ignore `minReceiveAmount` | full rate math + min-receive + daily limit + allowance + rounding guard |
| No pause/greenlist/blacklist/sanctions | all present, all admin-toggleable |
| `setStatus` flips status arbitrarily | reject keeps mTokens; approve pushes tokenOut + burns |
| mToken is a plain ERC20Mock | pausable + blacklist-gated transfers |

## 4. Recommended next steps

1. Rewrite the spec's "Protocol context and assumptions" as a numbered
   trust-assumption register (TA-1 … TA-n from section 2), each mapped to a
   test ID or an explicit "accepted risk" note.
2. Build one shared, realistic Midas mock set under
   `contracts/test/mocks/integrations/midas/` mirroring section 3's right
   column; replace the three ad-hoc mocks.
3. Adversarial unit/integration matrix per section 2 (A-1, A-2 first — they
   affect liquidatability and collateral truth).
4. Decide the A-1 policy (revert-through vs guarded valuation) before
   writing those tests — it changes the expected behavior.
5. Fork tests against pinned production proxies (per A-7) in `test/live/`
   style, opt-in via RPC env var.
