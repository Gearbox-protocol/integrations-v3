# KelpLRT Deposit Pool Adapter

## Contract overview

This contract is an adapter that allows Gearbox CAs to interact with the Kelp deposit pool, in order to deposit ETH and LST (stETH etc) directly into rsETH. The adapter uses KelpLRTDepositPoolGateway as its target in order to automatically wrap WETH into native ETH - as Kelp accepts ETH deposits in native ETH only, while Gearbox only supports WETH.

## Protocol overivew

Kelp is an LRT protocol that allows depositing ETH and some LSTs to mint rsETH - an LRT (liquid restaking token) that grants extra yield on ETH through restaking opportunities.

KelpLRTDepositPool is a contract that allows to deposit ETH/LSTs and atomically mint rsETH, based on the current exchange rate provided by the rsETH's oracle.

## Contract features

KelpLRTDepositPoolAdapter allows users to deposit into rsETH, using KelpLRTDepositPoolGateway as target.

Hence, it implements one function and its `diff` counterpart: `depositAsset` / `depositAssetDiff`.

The function approves the input asset to the gateway and and instructs the Credit Account to call the target with a specific calldata, then removes allowance.

The adapter also contains a whitelist of allowed input assets. Note that unlike the original Kelp deposit pools, the adapter does not have a separate function for native ETH deposits. Instead, to deposit ETH one would call `depositAsset` with WETH as input, and the gateway automatically handles the conversion.
