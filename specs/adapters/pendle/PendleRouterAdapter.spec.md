# BalancerV3 Router Adapter

## Contract overview

This contract is an adapter that allows Gearbox CAs to interact with the Pendle Router, in order to convert underlying assets into Pendle PTs or Pendle LPs.

## Protocol overivew

Pendle is a protocol for trading yield. It allows to wrap any yield-bearing token into a special wrapper called SY, which can then be split into PTs and YTs. YTs retain all of the yield from the original tokens, while PTs represent a claim to 1 unit of the underlying token at a specific expiry date. PTs and YTs are traded against each other on Pendle markets. Hence, Pendle provides a way to price yield, as well as provide a fixed yield bond-like product in the form of PT (since PTs cost less than the underlying before expiry). Pendle also allows users to provide liquidity into the PT/YT market in order to generate trading fees.

Users generally interact with the Pendle protocol through its Router, which enables various operations, including converting SY or underlying tokens to PT, providing liquidity, trading PT to YT, etc.

The Pendle adapter has the Pendle Router as its target.

## Contract features

PendleRouterAdapter allows users to convert underlying tokens into PTs and Pendle Market LP tokens, and back. It also allows users to redeem expired PTs 1:1 to underlying tokens (which is done through a separate function). Hence, it has 5 functions:

- `swapExactTokenForPt`
- `swapExactPtForToken`
- `redeemPyToToken`
- `addLiquiditySingleToken`
- `removeLiquiditySingleToken`

Each of these functions approves the participating tokens to the target contract (the Router), then instructs the Credit Account to call the target with a specific calldata relevant to the action, then removes the token allowance to prevent any possibility of external `transferFrom`'s on Credit Account tokens.

Additionally, the adapter contains a whitelist of allowed pairs. The whitelist is controlled with `setPairStatusBatch` and allows to whitelist PTs and LPs in a form of `(inputToken, pendleToken)`pair, where `inputToken` is a token used to enter or exit PTs/LPs, and `pendleToken` is a PT/LP token.
