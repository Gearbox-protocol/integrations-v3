# Kelp LRT Deposit pool Gateway

## Contract overview

This contract acts as an intermediary between the adapter and the Kelp deposit pool. The purpose of the contract is to automatically transform any incoming `depositAsset` calls with WETH into native ETH deposits, as Kelp supports native ETH deposits and does not support WETH.

## Protocol overview

Kelp is an LRT protocol that allows depositing ETH and some LSTs to mint rsETH - an LRT (liquid restaking token) that grants extra yield on ETH through restaking opportunities.

KelpLRTDepositPool is a contract that allows to deposit ETH/LSTs and atomically mint rsETH, based on the current exchange rate provided by the rsETH's oracle.

## Contract features

KelpLRTDepositPoolGateway has only one `depositAsset` function that facilitates deposits into Kelp - it transfers the input asset from the sender, performs a deposit, and transfers resulting rsETH to the sender.

In case of assets other than WETH, `depositAsset` in the Kelp deposit pool is simply called with the same parameters. In case of WETH, the incoming WETH is unwrapped and a payable function for native ETH (`depositETH`) is called instead.
