# Adapters

## Overview

Adapters are smart contracts that allow Gearbox users to interact with other protocols. For every credit manager and every target contract we want Credit Accounts from this manager to be able to interact with (e.g., Uniswap router, Yearn vault, Convex booster, etc.), there must be an adapter contract registered in the system.

Adapters are wrappers around target contracts, with similar interfaces, whose main task is to execute the call from the credit account to the target. However, there are other things they perform under the hood:

- handle token approvals;
- validate or change call parameters if it is needed to ensure safety of funds;
- contain a configurable whitelist of pools / pairs that is used to avoid interaction with potentially malicious code;

In addition, most adapters extend the interface of the original contract, in order to improve the API and smoothen out some interactions. For example, for each function that is present in the original contract, a corresponding \*\_diff function is added that helps with multi-step operations with unpredictable outputs. There may be altogether new functions as well, that wrap existing contract functions, in order to provide a more convenient interface.

## Adapter interaction flow

This is what happens when the user wants their Credit Account to interact with some protocol via an adapter:

1. The user prepares a call in a format `calls = (adapterAddress, callData)[]` to feed into Credit Facade (this is typically done by the Gearbox frontend);
2. The user calls `CreditFacade.multicall(calls)` with the prepared data;
3. There is usually more than one adapter interaction in the call list. For each, the Credit Facade calls the adapter with the provided callData.
4. The adapter performs input validation, approves the required tokens to the target contract, and passes a specifically formed calldata to the Credit Manager, which instructs the Credit Account to execute that calldata on a target contract;
5. The Credit Account calls the target contract with a provided calldata;
6. After all calls passed to `multicall` are processed, the Credit Manager performs a collateral check, to ensure that token balances after the target contract interaction cover debt.

## Security paradigm

There is a number of common patterns used in all adapters for security purposes:

- non-view adapter functions can only be called as part of the multicall, to ensure that there is always a collateral check afterwards, regardless of adapter implementation specifics.
- adapters always revoke target contracts' allowances for the credit accounts' tokens after operations;
- adapters aim to minimize arbitrary code execution by disallowing interaction with arbitrary tokens or contracts. In practice, this means that adapters capable of working with multiple assets or pools (such as UniswapV3 router adapter) implement some kind of whitelist to restrict interactions.

## What functionality should be in the adapter?

- wrappers for all required target contract functions that can modify account's state. Signatures of the functions must be the same, but returned values are replaced with a bool value that determines whether "safe prices" are used. Safe prices need to be used when a conversion a function implements can result in price impact / slippage. E.g., swap functions in DEX adapters (like UniswapV3) need to return `true`, while deposits into vaults at a fixed rate that can't be somehow manipulated can return `false`.
- versions of those functions that operate on the difference between the entire balance and some specified amount (these are called `diff` functions internally and are needed to handle multi-step operations properly);
- if the adapter interacts with a contract that can handle arbitrary tokens / pools, there must be a function to configure a whitelist, and each state-changing function must check that a pool it interacts with is included in the whitelist. The whitelist function must also check that all tokens that can potentially be touched by a pool interaction are allowed collaterals (via `_getTokenMaskOrRevert()`).
- if there is a pool whitelist, there must be a function to retrieve the list of allowed pools and what actions are allowed in each.

To make state-changing function secure, they must adhere to the following guidelines:

- they are called as part of the multicall and operate on the account on which it is executed;
- target contract approvals for credit account's tokens are revoked after the operation;
- tokens spent and received during the operation are recognized as collateral by the credit manager;
- ability to execute arbitrary code during the target contract call is minimized;
- tokens recipient is always the credit account.
- adapters must inherit AbstractAdapter and use its base functions / modifiers in all places where it is applicable;

## Helper contracts

Some adapters may have helper contracts that are intended to work in conjunction with an adapter to provide some extended functionality. There are 2 main types of helper contracts - gateways and phantom tokens.

### Gateways

Gateways are contracts that are set as the target for the adapter and serve as an intermediary between the adapter and the actual target contract. Usually gateways are used to unwrap WETH to ETH on the way to the target contract (for targets that work with native ETH only), or to call some auxiliary contract alongside the target (since adapters can only have one fixed address as target) - for example, of the target requires approvals through Permit2, this needs to be done in a gateway.

### Phantom tokens

Phantom tokens are special non-transferable tokens that represent non-tokenized positions. Phantom tokens have a `balanceOf` functions that outputs some quantity which can be treated as collateral. I.e., a phantom token of a non-tokenized farm can output the user's deposit into a farm, while a phantom token representing a delayed withdrawal in progress can output the expected amount of assets received at the end of withdrawal.

Adapters that work with phantom tokens need to implement two functions:

1. `withdrawPhantomToken` - this function converts a specific amount of passed phantom token into its underlying token.
2. `depositPhantomToken` - this function converts a specific amount of underlying into a phantom token. This can be non-implemented if the operation is one-way (for example, delayed withdrawals tokens cannot usually be deposited into).
