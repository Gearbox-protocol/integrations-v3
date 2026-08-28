# KelpLRT Withdrawal manager adapter

## Contract overview

This contract is an adapter that allows Gearbox CAs to interact with the Kelp withdrawal manager, in order to request and complete delayed withdrawal requests from Kelp, using a gateway as an intermediary.

The gateway requests withdrawals on behalf of CAs, using disposable accounts. When withdrawals mature, CAs can claim them via the adapter, at which point the gateway will transfer them the proceeds.

## Protocol overivew

Kelp is an LRT protocol that allows depositing ETH and some LSTs to mint rsETH - an LRT (liquid restaking token) that grants extra yield on ETH through restaking opportunities.

KelpLRTWithdrawalManager allows users to withdraw from rsETH into LSTs or ETH via a delayed withdrawal. The user first needs to initiate a withdrawal request, via `initiateWithdrawal`, transferring rsETH to the withdrawal manager. Once the withdrawal matures (after ~3 weeks), the user can claim it via `completeWithdrawal`, and the withdrawal manager will transfer back the requested asset based on the most actual exchange rate.

## Contract features

KelpLRTWithdrawalManagerAdapter allows user to request withdrawals via the gateway, and then claim them once they mature.

In order to request withdrawals, users can call `initiateWithdrawal` or `initiateWithdrawalDiff`, in order to claim them, users call `completeWithdrawal` with the required amount.

As withdrawals in the process of maturation are tracked via a phantom token, the adapter also has a `withdrawPhantomToken` as a standard phantom token unwrapping function - this function calls `completeWithdrawal` internally.

The adapter also contains a whitelist of allowed output assets. Note that allowing WETH as an asset and calling `initiateWithdrawal` with WETH would lead to the gateway withdrawing ETH and wrapping it, as Kelp does not support withdrawals in WETH, only native ETH.
