# BalancerV3 Router Gateway

## Contract overview

This contract acts as an intermediary between the adapter and the Balancer V3 Router. Since the Router requires approvals through Permit2 (relevant code [here](https://github.com/Uniswap/permit2/blob/main/src/AllowanceTransfer.sol)), and adapters only support normal ERC20 approval flow, an intermediate contract is required.

## Protocol overview

BalancerV3 is a DEX that allows users to swap between tokens and open LP positions (which provide liquidity for swaps and earn fees and other rewards).

BalancerV3 follows a singleton pattern, which means that the DEX has the main entry point (called Vault), which keeps all of the tokens, while BalancerV3 pools do not hold any value and simply contain logic to compute amounts for swaps, liquidity provision, etc. Pools contracts, however, are ERC20s and are minted to users when they provide liquidity. Each pool has 2 or more tokens that can be swapped between.

One can also interact with the protocol using various Routers, which provide a simple interface for common vault functions. BalancerV3RouterGateway (which is a target for this adapter) interacts with such a Router (its interface can be found [here](https://docs.balancer.fi/developer-reference/contracts/router-api.html)).

The Router will transfer relevant tokens from the gateway to the Vault, trigger the required vault operations and send the output tokens back.

## Contract features

BalancerV3RouterGateway implements several functions with the same signatures as the required functions in the Router. All functions generally work the same:

- The required token amount is transferred from the user;
- The gateway approves this amount of token the Permit2 and gives Permit2 allowance to the router;
- The gateway calls the router function with the same signature and parameters;
- The gateway sends the output token back to the caller;

To support tokens with fee on transfers, the vault tracks the actual amounts transferred to it from the user and the Router, and sends that exact amount. The gateway must not have a balance of more than 1 in any token between calls, unless someone deliberately sends tokens to it. It is permissible for tokens to get stuck in this case.

Additionally, `removeLiquiditySingleTokenExactIn` is an exception to the aforementioned flow, since liquidity withdrawals in BalancerV3 actually require normal approvals without Permit2.
