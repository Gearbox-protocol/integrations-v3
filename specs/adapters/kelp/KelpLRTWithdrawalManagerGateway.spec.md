# Kelp LRT Withdrawal Manager Gateway

## Contract overview

This contract acts as an intermediary between the adapter and the Kelp withdrawal manager, in order to facilitate withdrawals for Gearbox CAs. There are several elements that enable collateralizing withdrawals:

- The gateway itself, which acts as an entry point for CAs
- `KelpLRTWithdrawer`, which is a disposable account created for each CA and actually requests / claims withdrawals. Since most protocols with delayed withdrawals track relevant data by address, having a separate account for each CA greatly simplifies withdrawal tracking logic, while still leaving space for adding more functionality to the process.
- `KelpLRTWithdrawalPhantomToken`, which is a phantom token that tracks withdrawals in progress and allows using them as collateral. The balance of the phantom token is the sum of pending and claimable withdrawals, which are computed in `KelpLRTWithdrawer`.

## Protocol overview

Kelp is an LRT protocol that allows depositing ETH and some LSTs to mint rsETH - an LRT (liquid restaking token) that grants extra yield on ETH through restaking opportunities.

KelpLRTWithdrawalManager allows users to withdraw from rsETH into LSTs or ETH via a delayed withdrawal. The user first needs to initiate a withdrawal request, via `initiateWithdrawal`, transferring rsETH to the withdrawal manager. Once the withdrawal matures (after ~3 weeks), the user can claim it via `completeWithdrawal`, and the withdrawal manager will transfer back the requested asset based on the most actual exchange rate.

## Contract features

### KelpLRTWithdrawalManagerGateway

KelpLRTWithdrawalManagerGateway allows users to initiate and claim withdrawals via `initiateWithdrawal` and `completeWithdrawal`. These functions fetch the `KelpLRTWithdrawer` address associated with the calling CA (or create a new one), and call the respective functions in them (with the actual business logic mostly contained in `KelpLRTWithdrawer` itself). The gateway also exposes `getPendingAssetAmount` and `getClaimableAssetAmount`, which are used by the phantom token to compute total outstanding withdrawal value in underlying asset terms.

### KelpLRTWithdrawer

KelpLRTWithdrawer is created for each CA and initiates / completes withdrawals on behalf of this CA. Respective state-changing functions (such as `initiateWithdrawal` / `completeWithdrawal`) are gateway-only, so that the gateway is the sole entry-point for CAs.

For `initiateWithdrawal`, the contract assumes that rsETH was already transferred to it, so it only approves funds to the withdrawal manager and requests a withdrawal. In order to limit the gas expense for `getPendingAssetAmount` / `getClaimableAssetAmount`, the number of active withdrawals is limited to 5.

For `completeWithdrawal`, the contract computes the amount of matured withdrawals already on the contract (if they were previously partially claimed), and the amount of matured withdrawals that are still not claimed, as well as the number of unclaimed withdrawals. The contract then claims all withdrawals still in withdrawal manager (Kelp withdrawal manager requires calling the function once for each outstanding withdrawal). Then, the withdrawer sends the required amount to the account.

The withdrawer also provides `getPendingAssetAmount` and `getClaimableAssetAmount`, to retrieve the amount of pending withdrawals, and the amount of claimable (but not pending) withdrawals. For that, the withdrawer fetches all withdrawal requests for its own address and checks which withdrawals were processed by Kelp (based on whether their nonce is more-or-equal or less than the last locked nonce). For pending withdrawals, the withdrawer also converts the committed rsETH amount based on the current rate reported by Kelp.

### KelpLRTWithdrawalPhantomToken

The phantom token tracks withdrawals-in-progress in its balance in order for them to be usable as collateral. The balance is simply a sum of `getPendingAssetAmount` and `getClaimableAssetAmount`. For details on their computation, see previous section.
