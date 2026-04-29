# Securitize integration (helpers + adapters)

## Contract overview

This integration enables Gearbox Credit Accounts (CAs) to onramp into Securitize DS tokens and offramp back to stablecoins through Securitize's delayed redemption flow.

Scope covered in this spec:

- `SecuritizeLiquidator`
- `SecuritizeRedeemer`
- `SecuritizeRedemptionGateway`
- `SecuritizeRedemptionPhantomToken`
- `SecuritizeRedemptionGatewayAdapter`
- `SecuritizeOnRampAdapter`
- `SecuritizeSwapAdapter`

The design combines immediate swaps (onramp) with delayed, quarter-based redemptions (offramp). For delayed redemptions, each request is represented by a dedicated redeemer contract and collateralized via a phantom token.

## Protocol context and assumptions

Securitize DS tokens are transfer-restricted regulated securities. Transfers are only possible for registered investors and allowed addresses.

For Gearbox integration, this spec assumes:

- Credit Accounts and helper addresses required for flows are already registered/whitelisted through Securitize/Gearbox coordination.
- Offramp redemption is asynchronous and externally processed by Securitize, with no callback into Gearbox contracts when final settlement NAV is known.
- Redemption settlement arrives as stablecoins to the redeemer address after Securitize processing.
- `stableCoinToken` in this integration is the ERC4626 wrapper `underlying` asset (`IERC4626(underlying).asset()`), and is the stablecoin leg swapped against DS token in onramp/offramp flows.
- For the relevant Credit Manager, allowed collateral universe is restricted to exactly: wrapper `underlying` (ERC4626 over stablecoin), DS token underlying stablecoin, DS token, and Securitize redemption phantom token.
- For the relevant Credit Manager, only one Securitize `RedemptionGateway` is configured as adapter target.

## Architecture

Main components:

- **Adapters**: contracts called by `CreditFacade` during `multicall`; they forward execution instructions through `CreditManager` to the CA.
- **Redemption gateway**: fixed adapter target that orchestrates redeemer lifecycle.
- **Redeemer clones**: one clone per redemption request, each holding request-level state (`startingNavRate`, pending amount, claimable balance).
- **Phantom token**: exposes aggregate pending redemption value as collateral.
- **Liquidator helper**: special contract that can temporarily enable redeemer transfer and perform liquidation-specific pending redemption handling.

High-level data flow:

1. Onramp:
   - User submits adapter calls via `CreditFacade.multicall` (e.g. `SecuritizeOnRampAdapter.swap/swapDiff` or `SecuritizeSwapAdapter.buy...`).
   - `CreditFacade` calls the adapter, and adapter routes target calldata through `CreditManager` for CA execution.
2. Offramp request:
   - User submits `SecuritizeRedemptionGatewayAdapter.redeem/redeemDiff` through `CreditFacade.multicall`.
   - Gateway clones a new `SecuritizeRedeemer`, links it to CA, transfers DS tokens into it, and calls `redeem`.
   - Redeemer forwards DS tokens to Securitize redemption EOA and records `startingNavRate`.
3. Offramp settlement:
   - Securitize sends stablecoins to the redeemer when processed.
   - User submits adapter `claim` through `CreditFacade.multicall`; gateway calls redeemer `claim`, redeemer transfers stablecoins to CA.
4. Liquidation of pending redemptions:
   - `SecuritizeLiquidator` can transfer ownership of unclaimed redeemers from CA to liquidator recipient under strict checks.

## Contract features

### `SecuritizeRedeemer`

Purpose:

- Disposable redemption position container for one redemption request.
- Isolated state per request simplifies accounting and transfer during liquidation.

Key behavior:

- Constructor sets immutable references: DS token, stablecoin, redemption EOA, NAV provider.
- `gateway` is immutable `msg.sender` at deployment; all mutating functions are `gatewayOnly`.
- `redeem(dsTokenAmount)`:
  - transfers DS tokens to redemption EOA,
  - snapshots `startingNavRate` and `startingTimestamp`,
  - sets `pendingDsTokenAmount`,
  - one-time only via `alreadyRedeemed`.
- `claim()` transfers all stablecoin balance from redeemer to `account` and zeroes `pendingDsTokenAmount`.
- Valuation functions:
  - `getCurrentRedemptionValue()` uses current NAV.
  - `getRedemptionAmount()` returns `max(currentStablecoinBalance, min(current-based value, starting-based value))`.

Security and pricing rationale:

- `min(startingNAV, currentNAV)` protects against overpricing when post-redemption NAV rises and no definitive settlement callback exists.
- Taking `max(..., currentStablecoinBalance)` ensures already-received balances on redeemers are never understated in phantom valuation.
- Request-level separation prevents cross-request state contamination and enables selective transfer/liquidation.

### `SecuritizeRedemptionGateway`

Purpose:

- Main target contract for redemption flow.
- Owns and manages redeemer sets per account.

State model:

- `redeemersByAccount[account]`: all redeemers owned by account.
- `unclaimedRedeemers[account]`: subset still expected to hold or receive settlement.

Key behavior:

- `redeem(dsTokenAmount)`:
  - returns early for zero amount (no-op),
  - clones `masterRedeemer`,
  - assigns CA ownership via `setAccount`,
  - registers helper account with whitelister,
  - transfers DS tokens CA -> redeemer,
  - calls redeemer `redeem`.
- `claim(redeemers[])`:
  - validates ownership for each redeemer,
  - calls redeemer `claim`,
  - removes redeemer from `unclaimedRedeemers`.
- Claimed redeemers are intentionally retained in `redeemersByAccount` forever, so users can still claim any late or accidentally sent stablecoins from previously used redeemers.
- `transferRedeemer(redeemer, newAccount)`:
  - only if caller owns redeemer,
  - only if transfer master allows transfer and redeemer is still unclaimed,
  - only if `newAccount` is an approved wallet in Securitize registry service,
  - moves ownership and unclaimed status from old to new account,
  - updates redeemer `account`.
- `getRedemptionAmount(account)`:
  - sums `getRedemptionAmount()` across unclaimed redeemers.
- Zero-amount `redeem` is treated as allowed/no-op from an economic perspective (no meaningful redemption exposure is created).

Access and transfer restrictions:

- Gateway itself does not expose privileged admin logic for transfer.
- Transfer authorization is delegated to external `transferMaster` (`isTransferAllowed()`), expected to be the liquidator in this integration.
- Gateway enforces a hard limit of 10 unclaimed redeemers per account.

### `SecuritizeRedemptionPhantomToken`

Purpose:

- Represents estimated value of pending/claimable redemption positions as collateral.

Key behavior:

- Underlying token metadata comes from gateway stablecoin.
- `balanceOf(account)` proxies to `gateway.getRedemptionAmount(account)`.
- Non-transferable phantom semantics inherited from `PhantomERC20`.
- `getPhantomTokenInfo()` links phantom token to `(redemptionGateway, stableCoinToken)`.

Audit relevance:

- Collateral value depends on gateway/redeemer valuation logic, especially NAV oracle correctness and min(starting,current) cap.

### `SecuritizeRedemptionGatewayAdapter`

Purpose:

- Adapter for delayed redemption operations via gateway, executed in the standard Gearbox path (`CreditFacade` -> adapter -> `CreditManager` -> CA target call).

Key behavior:

- Constructor caches DS/stablecoin and validates phantom token belongs to the same gateway.
- `redeem(dsTokenAmount)` and `redeemDiff(leftoverAmount)`:
  - approve DS token and call gateway `redeem`.
- `claim(redeemers[])`: calls gateway `claim`.
- `transferRedeemer(redeemer, newAccount)`: calls gateway transfer function.
- `withdrawPhantomToken` and `depositPhantomToken` are intentionally unimplemented (revert).

Adapter return semantics:

- `redeem` and successful `redeemDiff` return `true` (safe prices required, as redemption is treated as a swap into phantom-tokenized pending claim value).
- Safe pricing for redemption is intentional: post-redeem collateral checks should use `min(mainPrice, reservePrice)` to enforce a buffer (e.g., against interest accrual risk during the delayed redemption window).
- `claim` returns `false` (claiming settled stablecoins does not require safe-price mode).
- `transferRedeemer` returns `true` (safe prices requested in Gearbox multicall pipeline).

### `SecuritizeOnRampAdapter`

Purpose:

- Immediate stablecoin -> DS token onramp via Securitize onramp contract.

Key behavior:

- `swap(liquidityAmount, minOutAmount)` exact-in with min output protection.
- `swapDiff(leftoverAmount, rateMinRAY)` spends full stablecoin balance minus leftover; computes `minOutAmount = amount * rateMinRAY / RAY`.
- Uses safe approve/execute pattern from `AbstractAdapter`.

### `SecuritizeSwapAdapter`

Purpose:

- Immediate stablecoin -> DS token buy flow via Securitize swap contract.

Key behavior:

- `buy(uint256,uint256)` forwards calldata directly with approval.
- `buyExactIn(stableCoinAmount)` computes DS amount via `calculateDsTokenAmount`, then calls `buy(dsAmount, stableAmount)`.
- `buyExactInDiff(leftoverAmount)` spends full stablecoin balance minus leftover.

## Liquidation-specific logic (`SecuritizeLiquidator`)

Purpose:

- Handles liquidation of accounts with pending redemptions by transferring redeemer ownership to liquidator/recipient under additional fairness constraints.

Liquidator-specific assumptions:

- Collateral set is constrained to four assets only: wrapper `underlying`, stablecoin, DS token, and redemption phantom token.
- A single redemption gateway is configured for the Credit Manager, so gateway selection ambiguity is out of scope.

Execution flow (`liquidatePendingRedemption`):

1. Validates gateway transfer master equals the liquidator contract.
2. Validates the address is a known Securitize KYC credit account (`securitizeKycFactory.isCreditAccount`).
3. Loads credit manager/facade from CA.
4. Optionally applies provided price updates through `PriceFeedStore`.
5. Requires account is currently liquidatable (`debt > 0` and TWV < total debt).
6. Reads liquidation discount from credit manager fees.
7. Fetches all unclaimed redeemers of CA.
8. Computes:
   - `collateralValue`: sum of current redeemer value + DS balance converted to underlying,
   - `liquidityAmount`: underlying + stablecoin balances on CA plus settled stablecoin balances already on redeemers, then discounted by liquidation discount.
9. Reverts if `liquidityAmount >= totalDebt` (normal liquidation should be used; no redeemer transfer needed).
10. Computes required liquidator payment amount:

- `underlyingAmount = collateralValue * liquidationDiscount / PERCENTAGE_FACTOR`.

11. Sets `isTransferAllowed = true`, executes liquidation multicall through `liquidateCreditAccount`, then sets `isTransferAllowed = false` on success:

- transfer each redeemer to liquidator recipient through adapter,
- add provided underlying collateral,
- withdraw DS tokens from CA to recipient **only if DS balance is non-zero**,
- call underlying adapter `depositDiff(1)` **only if stablecoin balance on CA is non-zero**.

12. Calls `CreditFacade.liquidateCreditAccount`.

Fairness and risk intent:

- Uses **current NAV** for pending redemption value at liquidation time, rather than initial NAV snapshot, reducing borrower disadvantage from stale starting NAV.
- Blocks this path when immediately available liquidity already covers debt, preventing unnecessary transfer of pending redemption rights.

## Core invariants and security properties (AI audit focus)

- **Gateway-only mutability in redeemer**: only gateway can set account/redeem/claim.
- **Single-use redeemer**: each redeemer can be redeemed once (`alreadyRedeemed`).
- **Pending value cap**: redeem valuation for collateral is capped by starting NAV via `min(starting,current)`.
- **Transfer gating**: redeemer transfer requires both account ownership and `transferMaster.isTransferAllowed()`.
- **Unclaimed-set consistency**: transfer and claim operations update unclaimed sets; claimed redeemers should no longer contribute to phantom balance.
- **Adapter call restrictions**: state-changing adapter methods are `creditFacadeOnly`.
- **Token allowlist assumptions**: constructors call `_getMaskOrRevert` for all touched tokens/phantom token.
- **Liquidation preconditions**:
  - only for credit accounts recognized by Securitize KYC factory,
  - only for truly liquidatable accounts,
  - only when transfer master binding is correct,
  - only when account+redeemer liquid balances do not already cover debt.
- **Constrained collateral universe**: liquidation math and call composition rely on the manager using only wrapper underlying, stablecoin, DS token, and phantom token as collateral assets.
- **Single gateway configuration**: liquidation path assumes one canonical redemption gateway per Credit Manager.
- **Oracle/NAV trust**:
  - redeemer valuation relies on external NAV provider,
  - liquidation valuation additionally depends on Gearbox price oracle conversion for DS token on-account balance.

## Trust boundaries and external dependencies

- Securitize contracts/interfaces:
  - Onramp/swap target contracts,
  - NAV provider,
  - whitelister and redemption process assumptions.
- Gearbox core:
  - CreditFacade/CreditManager collateral checks and liquidation semantics,
  - price feed store update mechanism,
  - adapter masking/token enablement.
- Operational dependency:
  - Securitize must deliver stablecoin settlement to redeemer addresses offchain/onchain without callback coupling.

## Known design tradeoffs

- Final redemption proceeds are not known onchain at request time; valuation is estimate-based.
- `min(starting,current)` is conservative for collateral and prevents overstatement when NAV rises after processing.
- Liquidation path intentionally diverges from usual pending valuation by using current NAV and custom liquidity guard for borrower fairness (triggered liquidation context vs passive pending-redemption accounting).
- Redeemer-per-request increases object count but improves isolation and transferability.

## Potential audit hotspots

- Consistency between comments/intended behavior and actual liquidation multicall composition.
- Correctness of conditional liquidation calls (`withdrawCollateral` for DS token and `depositDiff(1)` for stablecoin wrapping) and whether they can fail unexpectedly for specific adapter setups.
- Correctness of stablecoin-wrapper accounting assumptions (underlying is an ERC4626 wrapper over the same stablecoin used in redemption).
- Oracle desync risk between NAV provider and Gearbox price oracle during stressed conditions.
