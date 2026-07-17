# Midas integration (helpers + adapters)

## Contract overview

This integration enables Gearbox Credit Accounts (CAs) to onramp into Midas mTokens and offramp back to stablecoins or other supported assets through Midas issuance and redemption vaults.

Scope covered in this spec:

- `MidasGateway`
- `MidasRedeemer`
- `MidasRedemptionVaultPhantomToken`
- `MidasGatewayAdapter`
- `MidasLiquidator`

The design combines immediate issuance/redemption (onramp/offramp) with delayed redemption requests (offramp). For delayed redemptions, each request is represented by a dedicated redeemer clone and collateralized via a per-output-token phantom token.

## Protocol context and assumptions

Midas mTokens are issued and redeemed through Midas issuance and redemption vaults. mTokens may be permissioned (greenlist-gated) depending on deployment configuration.

For Gearbox integration, this spec assumes:

- Credit Accounts and helper addresses required for flows are eligible to interact with the gateway (see eligibility checks below).
- Delayed offramp redemption is asynchronous and externally processed by Midas; there is no callback into Gearbox contracts when final settlement is known.
- Redemption settlement arrives as `quoteToken` on the redeemer address after Midas processing.
- Each gateway supports one immutable `quoteToken` used for issuance, instant redemption, and delayed redemption settlement.
- The gateway deploys its `MidasRedemptionVaultPhantomToken` in the constructor.
- Instant issuance (`depositInstant`) and instant redemption (`redeemInstant`) are synchronous swaps through Midas vaults.
- For access-controlled deployments, the gateway reads the access control contract from both vaults and requires them to match.
- For permissioned deployments, the gateway temporarily grants and revokes `GREENLISTED_ROLE` on itself and redeemer clones around Midas vault interactions.
- The gateway deploys its own `MidasLiquidator` in the constructor and sets it as `transferMaster` for liquidation flows that transfer redeemer ownership.

## Architecture

Main components:

- **Adapter**: unified `MidasGatewayAdapter` called by `CreditFacade` during `multicall`; routes execution through `CreditManager` to the CA, which calls the gateway.
- **Gateway**: fixed adapter target that orchestrates issuance, instant redemption, delayed redemption, and redeemer lifecycle.
- **Redeemer clones**: one clone per delayed redemption request, each holding request-level state (`requestId`, pending/claimable balances).
- **Phantom token**: one constructor-deployed token per gateway; exposes aggregate pending + claimable redemption value as collateral.
- **Liquidator helper**: deployed by the gateway constructor and set as `transferMaster`, temporarily enabling redeemer transfers during liquidation multicalls.

High-level data flow:

1. Onramp (instant issuance):
   - User submits `MidasGatewayAdapter.depositInstant/depositInstantDiff` via `CreditFacade.multicall`.
   - Adapter approves quote token and calls gateway `depositInstant`.
   - Gateway pulls `quoteToken` from CA, issues mToken via Midas issuance vault, returns mToken to CA.
2. Offramp (instant redemption):
   - User submits `MidasGatewayAdapter.redeemInstant/redeemInstantDiff` via `CreditFacade.multicall`.
   - Gateway pulls mToken from CA, redeems via Midas redemption vault, returns `quoteToken` to CA.
3. Offramp (delayed redemption request):
   - User submits `MidasGatewayAdapter.redeemRequest/redeemRequestDiff` via `CreditFacade.multicall`.
   - Gateway clones a new `MidasRedeemer`, links it to CA, transfers mToken into it, and calls redeemer `requestRedeem`.
   - Redeemer submits redemption request to Midas redemption vault and records `requestId`.
4. Offramp settlement:
   - Midas processes the request and sends `quoteToken` to the redeemer when fulfilled.
   - User submits adapter `withdraw` or `withdrawPhantomToken` via `CreditFacade.multicall`; gateway iterates pending redeemers and calls redeemer `withdraw`, which transfers `quoteToken` to CA.
5. Liquidation of pending redemptions:
   - `MidasLiquidator` sets `isTransferAllowed = true`, forwards liquidator-supplied multicall to `CreditFacade.liquidateCreditAccount` (including redeemer transfers), then resets the flag.

## Contract features

### `MidasRedeemer`

Purpose:

- Disposable redemption position container for one delayed redemption request.
- Isolated state per request simplifies accounting and transfer during liquidation.

Key behavior:

- Constructor sets immutable references: redemption vault, mToken, quote token, mToken data feed; `gateway` is immutable `msg.sender` at deployment.
- All mutating functions except `clearCancelledRequest` are `gatewayOnly`.
- `setAccount(account)`: gateway sets the owning CA.
- `requestRedeem(amountMTokenIn)`:
  - approves mToken to redemption vault,
  - calls `redeemRequest` on vault, stores `requestId`,
  - sets `alreadyRedeemed = true` (one-time only).
- `withdraw(amount)`: transfers `quoteToken` from redeemer to `account`.
- Valuation functions:
  - `pendingTokenOutAmount()`: computes expected output from pending request using **current** mToken data feed rate and **request-snapshot** `tokenOutRate`; returns 0 if request is processed (`status == 1`) or manually cleared.
  - `claimableTokenOutAmount()`: returns on-chain `quoteToken` balance on the redeemer.
- `clearCancelledRequest(amount)`:
  - callable by anyone when vault request `status == 2` (cancelled) and not yet manually cleared,
  - requires `amount >=` projected output at request rates (`mTokenRate`, `tokenOutRate` from request),
  - pulls `quoteToken` from caller and sets `isManuallyCleared = true`.

Redemption request status (from Midas vault `redeemRequests`):

- `status == 0`: pending/active (contributes to `pendingTokenOutAmount`).
- `status == 1`: processed/fulfilled (`pendingTokenOutAmount` returns 0; value moves to `claimableTokenOutAmount` via on-chain balance).
- `status == 2`: cancelled (eligible for `clearCancelledRequest`).

Security and pricing rationale:

- Pending valuation uses the **current** mToken data feed rate, so collateral tracks live mToken pricing rather than a frozen snapshot.
- `tokenOutRate` is fixed at request time from the vault request record.
- Claimable amount is always the actual on-chain balance, so already-received settlement is never understated.
- Request-level separation prevents cross-request state contamination and enables selective transfer/liquidation.

### `MidasGateway`

Purpose:

- Unified target for issuance, instant redemption, and delayed redemption flows.
- Owns and manages redeemer sets per account.

State model:

- `accountToRedeemers[account]`: all redeemers ever created for the account (retained indefinitely).
- `accountToPendingRedeemers[account]`: subset still contributing to phantom collateral (pending or claimable balance > 0).

Key behavior:

- **Eligibility** (`onlyEligibleAccount` on mutating flows except `withdraw`/`withdrawFromRedeemer`):
  - caller must be a Gearbox credit account (`contractType == "CREDIT_ACCOUNT"`),
  - credit manager must be set and borrower non-zero,
  - if `allowedMarketConfigurator != 0`, credit manager must be registered in that market's contracts register,
  - if `checkBorrowerGreenlist`, borrower must have `GREENLISTED_ROLE` on Midas access control.
- `depositInstant(amountToken, minReceiveAmount, referrerId)`:
  - pulls `quoteToken` from caller, converts amount to 18 decimals for Midas,
  - temporarily greenlists gateway, calls issuance vault `depositInstant`, revokes greenlist,
  - transfers received mToken back to caller.
- `redeemInstant(amountMTokenIn, minReceiveAmount)`:
  - pulls mToken from caller, temporarily greenlists gateway,
  - calls redemption vault `redeemInstant` (min receive in 18 decimals),
  - transfers `quoteToken` back to caller.
- `requestRedeem(amountMTokenIn, extraData)`:
  - clones `masterRedeemer`, assigns CA ownership,
  - transfers mToken from caller to redeemer,
  - temporarily greenlists redeemer, calls redeemer `requestRedeem`, revokes greenlist,
  - optionally logs via `redemptionLogger`.
- `withdraw(amount)`:
  - iterates `accountToPendingRedeemers[msg.sender]` in set order,
  - withdraws from each redeemer's claimable balance until `amount` is satisfied,
  - removes redeemer from pending set when `pendingTokenOutAmount() == 0` after withdrawal.
- `withdrawFromRedeemer(redeemer, amount)`:
  - requires redeemer in `accountToRedeemers[msg.sender]` (not necessarily pending),
  - allows recovery of stranded funds from redeemers no longer counted as collateral.
- `transferRedeemer(redeemer, newAccount)`:
  - only if redeemer is in caller's pending set and `transferMaster.isTransferAllowed()`,
  - if `checkBorrowerGreenlist`, `newAccount` must be greenlisted,
  - moves redeemer between accounts in both redeemer sets and updates redeemer `account`.
- `pendingAndClaimableTokenOutAmounts(account)`: sums pending and claimable across pending redeemers.
- Hard limit of `MAX_PENDING_REDEEMERS_PER_ACCOUNT` (10) pending redeemers per account.
- Constructor deploys `MidasRedeemer` (master clone implementation), `MidasLiquidator` (set as `transferMaster`), and `MidasRedemptionVaultPhantomToken`.

Access and transfer restrictions:

- Gateway has no privileged admin logic for transfer; authorization is delegated to its constructor-deployed `transferMaster` (`MidasLiquidator.isTransferAllowed()`).
- Greenlist grant/revoke is scoped to gateway and redeemer addresses during vault interactions only.

### `MidasRedemptionVaultPhantomToken`

Purpose:

- Represents estimated value of pending + claimable delayed redemption positions for the gateway quote token as collateral.

Key behavior:

- One phantom token per gateway, deployed in `MidasGateway` constructor.
- Underlying token metadata comes from `quoteToken` (name, symbol, decimals).
- `balanceOf(account)` = `pendingAmount + claimableAmount` from `gateway.pendingAndClaimableTokenOutAmounts(account)`.
- Non-transferable phantom semantics inherited from `PhantomERC20`.
- `getPhantomTokenInfo()` links phantom token to `(gateway, quoteToken)`.

Audit relevance:

- Collateral value depends on gateway/redeemer valuation logic, especially mToken data feed correctness and Midas vault request status handling.
- Each gateway tracks exactly one quote-token redemption leg.

### `MidasGatewayAdapter`

Purpose:

- Unified adapter for issuance, instant redemption, delayed redemption, and phantom token operations via the gateway.

Key behavior:

- Constructor caches `mToken`, `quoteToken`, and `phantomToken`, validating all three via `_getMaskOrRevert`.
- **Issuance**:
  - `depositInstant(amountToken, minReceiveAmount, _)`: approves quote token and calls gateway `depositInstant` with immutable `referrerId`.
  - `depositInstantDiff(leftoverAmount, rateMinRAY)`: spends full quote-token balance minus leftover; computes `minReceiveAmount = amount * rateMinRAY / RAY`.
- **Instant redemption**:
  - `redeemInstant(amountMTokenIn, minReceiveAmount)`.
  - `redeemInstantDiff(leftoverAmount, rateMinRAY)`.
- **Delayed redemption**:
  - `redeemRequest(amountMTokenIn)` and overload with `extraData`.
  - `redeemRequestDiff(leftoverAmount)` and overload with `extraData`.
- **Withdrawal**:
  - `withdraw(amount)`: calls gateway `withdraw`.
  - `withdrawFromRedeemer(redeemer, amount)`: calls gateway `withdrawFromRedeemer`.
  - `withdrawPhantomToken(token, amount)`: validates the token is the gateway phantom token, calls gateway `withdraw`.
  - `depositPhantomToken`: intentionally unimplemented (reverts).
- **Transfer**:

  - `transferRedeemer(redeemer, newAccount)`: calls gateway `transferRedeemer`.
    Adapter return semantics (safe pricing flag):

- `redeemRequest` / `redeemRequestDiff` (and `extraData` variants): return `true` when a redemption is executed (safe prices required, as redemption is treated as a swap into phantom-tokenized pending claim value).
- `redeemRequestDiff` when balance `<= leftover`: returns `false` (no-op).
- All other operations (`depositInstant`, `depositInstantDiff`, `redeemInstant`, `redeemInstantDiff`, `withdraw`, `withdrawFromRedeemer`, `transferRedeemer`, `withdrawPhantomToken`): return `false`.

## Liquidation-specific logic (`MidasLiquidator`)

Purpose:

- Acts as `transferMaster` for Midas gateways, enabling redeemer transfers for the duration of a liquidation.
- Unlike Securitize RWA liquidation, performs **no** collateral/liquidity math; pending redemption valuation is identical for collateral accounting and liquidation.

Liquidator-specific assumptions:

- Each gateway deploys its own `MidasLiquidator` in the constructor and sets it as `transferMaster`.
- Liquidator supplies the full liquidation multicall (including redeemer transfers, collateral additions, withdrawals) externally.
- Pending redemption value at liquidation time uses the same logic as normal collateral checks (current mToken data feed rate).

Execution flow (`liquidateWithRedeemerTransfers`):

1. Validates `gateway.transferMaster() == address(this)`.
2. Validates gateway has a non-zero adapter in the credit account's credit manager.
3. Pre-processes `addCollateral` calls in the supplied multicall: pulls tokens from `msg.sender` (liquidator) and approves credit manager.
4. Sets `isTransferAllowed = true`.
5. Calls `CreditFacade.liquidateCreditAccount(creditAccount, msg.sender, calls, lossPolicyData)`.
6. Sets `isTransferAllowed = false`.
7. Post-processes `addCollateral` calls: returns any leftover approved tokens from liquidator contract back to `msg.sender`.

Fairness and risk intent:

- No custom liquidation valuation path; borrower and liquidator see the same pending redemption pricing as the credit manager's collateral checks.
- Liquidator is responsible for composing correct multicall (redeemer transfers, collateral operations) for the specific market collateral set.

## Core invariants and security properties (AI audit focus)

- **Gateway-only mutability in redeemer**: only gateway can `setAccount`, `requestRedeem`, and `withdraw` on redeemers.
- **Single-use redeemer**: each redeemer can submit one redemption request (`alreadyRedeemed`).
- **Pending-set consistency**: `withdraw` and `transferRedeemer` update `accountToPendingRedeemers`; fully settled redeemers should no longer contribute to phantom balance.
- **Claimed redeemers retained**: `accountToRedeemers` keeps all historical redeemers so `withdrawFromRedeemer` can recover stranded funds.
- **Transfer gating**: redeemer transfer requires pending-set membership, caller ownership, and `transferMaster.isTransferAllowed()`.
- **Eligibility gating**: issuance, instant redemption, delayed redemption requests, and redeemer transfers require eligible credit account (and greenlisted borrower when configured).
- **Adapter call restrictions**: state-changing adapter methods are `creditFacadeOnly`; configuration is `configuratorOnly`.
- **Token allowlist assumptions**: constructors and configuration call `_getMaskOrRevert` for collateral tokens and phantom tokens.
- **Delayed redemption phantom**: adapter exposes the single gateway phantom token for pending redemption collateral.
- **Unclaimed redeemer cap**: max 10 pending redeemers per account.
- **Greenlist lifecycle**: gateway/redeemer addresses are greenlisted only for the duration of Midas vault calls when access control is configured.
- **Oracle/data feed trust**: pending redemption valuation relies on Midas mToken data feed (`getDataInBase18`) and vault request rates.

## Trust boundaries and external dependencies

- Midas contracts/interfaces:
  - Issuance vault (`depositInstant`),
  - Redemption vault (`redeemInstant`, `redeemRequest`, `redeemRequests`),
  - mToken data feed,
  - access control (greenlist),
  - redemption request processing and settlement assumptions.
- Gearbox core:
  - CreditFacade/CreditManager collateral checks and liquidation semantics,
  - adapter masking/token enablement,
  - phantom token collateral framework.
- Operational dependency:
  - Midas must deliver `tokenOut` settlement to redeemer addresses without callback coupling.
  - Permissioned deployments require gateway to hold greenlist grant authority on Midas access control.

## Known design tradeoffs

- Final redemption proceeds are not known onchain at request time for delayed redemptions; valuation is estimate-based using current mToken rate.
- Pending valuation uses current mToken data feed rate (not request-time mToken rate), which can diverge from Securitize's conservative `min(starting, current)` approach.
- Redeemer-per-request increases object count but improves isolation and transferability.
- `MidasLiquidator` delegates liquidation call composition to the caller rather than encoding market-specific logic onchain.
- `withdraw` iterates pending redeemers in set insertion order (not explicitly sorted by age or amount).
- `clearCancelledRequest` is a permissionless recovery path for cancelled Midas requests, relying on external party to supply funds at request rates.

## Potential audit hotspots

- Correctness of `pendingTokenOutAmount` when mToken data feed rate moves between request and settlement.
- Interaction between processed request status (`status == 1`) and claimable balance accounting during partial withdrawals.
- Greenlist grant/revoke timing: ensure no window where unauthorized party can interact with Midas vaults via a greenlisted helper address.
- Eligibility checks: market configurator binding, borrower greenlist, and credit account type validation completeness.
- `withdraw` aggregation logic across multiple redeemers: partial withdrawals, remainder handling, pending-set removal conditions.
- `withdrawFromRedeemer` vs `withdraw`: access control difference (all redeemers vs pending only) and stranded-fund recovery.
- `transferRedeemer` greenlist check on `newAccount` during liquidations.
- Adapter phantom token handling: only the gateway phantom token should be accepted by `withdrawPhantomToken`.
- `MidasLiquidator` collateral forwarding: correctness of `addCollateral` pre/post processing and token approval cleanup.
- `clearCancelledRequest`: economic correctness of min-amount check and interaction with phantom collateral after manual clear.
- Consistency between adapter safe-pricing return values and CreditFacade collateral check expectations for delayed vs instant flows.
- Reentrancy: gateway uses `nonReentrant`; verify cross-contract call ordering with Midas vaults and greenlist operations.
