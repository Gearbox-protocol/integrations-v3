# BalancerV3 Router Adapter

## Contract overview

This contract is an adapter that allows Gearbox CAs to interact with the BalancerV3 vault (via Balancer's router), in order to swap through BalancerV3 pools and open BalancerV3 LP positions.

The adapter actually has BalancerV3RouterGateway as its target, since BalancerV3 requires token approvals through Permit2, which cannot normally be supported by adapters. See the corresponding spec for BalancerV3RouterGateway details.

## Protocol overivew

BalancerV3 is a DEX that allows users to swap between tokens and open LP positions (which provide liquidity for swaps and earn fees and other rewards).

BalancerV3 follows a singleton pattern, which means that the DEX has the main entry point (called Vault), which keeps all of the tokens, while BalancerV3 pools do not hold any value and simply contain logic to compute amounts for swaps, liquidity provision, etc. Pools contracts, however, are ERC20s and are minted to users when they provide liquidity. Each pool has 2 or more tokens that can be swapped between.

One can also interact with the protocol using various Routers, which provide a simple interface for common vault functions. BalancerV3RouterGateway (which is a target for this adapter) interacts with such a Router (its interface can be found [here](https://docs.balancer.fi/developer-reference/contracts/router-api.html)).

The Router will transfer relevant tokens from the user (in this case, BalancerV3Gateway) to the Vault, trigger the required vault operations and send the output tokens back.

## Contract features

BalancerV3RouterAdapter allows users to swap through BalancerV3 pools, as well as provide liquidity by depositing underlying tokens.

Hence, it implements three functions:

- `swapSingleTokenExactIn` - used for swaps between 2 tokens in the pool
- `addLiquidityUnbalanced` - used to provide liquidity in exact quantities of 1 or more tokens
- `removeLiquiditySingleTokenExactIn` - used to remove liquidity in 1 token with an exact amount of LP tokens burned.

Each function also has its "diff" counterpart - since a conversion from Gearbox's underlying token to the target token can take several steps, and the output of each step cannot be predicted exactly, these functions are used to keep the exact amount on the account (usually the amount that was already there), while swapping the rest.

Each of these functions approves the participating tokens to the target contract (the gateway), then instructs the Credit Account to call the target with a specific calldata relevant to the action, then removes the token allowance to prevent any possibility of external `transferFrom`'s on Credit Account tokens.

Additionally, the adapter contains a whitelist of allowed pools. This whitelist is required to avoid arbitrary code execution - if any pool is allowed, then a potential attacker can interact with a pool that has a token executing some malicious code in its `transfer` function. The whitelist is controlled with `setPoolStatusBatch` and allows to enable / disable pool actions granularly (i.e., each pool can be configured to only allow swaps, or only allow exits, etc).
