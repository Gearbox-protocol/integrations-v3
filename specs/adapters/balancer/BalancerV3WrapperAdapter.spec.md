# BalancerV3 Router Adapter

## Contract overview

This contract is an adapter that allows Gearbox CAs to interact with wrapper tokens for Balancer BPTs that protect against flash minting BPTs from the vault.

## Protocol overivew

BalancerV3 is a DEX that allows users to swap between tokens and open LP positions (which provide liquidity for swaps and earn fees and other rewards).

BalancerV3 follows a singleton pattern, which means that the DEX has the main entry point (called Vault), which keeps all of the tokens, while BalancerV3 pools do not hold any value and simply contain logic to compute amounts for swaps, liquidity provision, etc. Pools contracts, however, are ERC20s and are minted to users when they provide liquidity. Each pool has 2 or more tokens that can be swapped between.

BalancerV3Vault allows any user to perform a sequence of actions (including minting BPTs) before actually settling pool underlying balances. The vault also performs a callback to the caller when this is done - the mechanism is somewhat analogous to a flash loan. This means that a potential attacker can mint a near-infinite amount of unbacked BalancerV3 LP tokens and provide them as collateral to an external protocol (such as Gearbox). This is mechanically similar to flash loans and most attack vectors are prevented by the fact that the attacker needs to settle their underlying token debt with the Vault at the end. However, due to a possibility of extremely large sums being minted, there might be obscure attacks that utilize precision errors.

For that reason, BalancerV3 recommends using special wrappers for BPT tokens, instead of BPTs themselves, as collateral. A wrapper prevents its minting or burning while the vault is unlocked (i.e., in a potentially non-settled state), which prevents this attack.

## Contract features

BalancerV3WrapperAdapter allows users to wrap and unwrap BPTs into a wrapper token. Hence it has 2 functions:

- `mint`
- `burn`

Each of these functions approves the participating tokens to the target contract (the wrapper token), then instructs the Credit Account to call the target with a specific calldata relevant to the action, then removes the token allowance to prevent any possibility of external `transferFrom`'s on Credit Account tokens. Each function also has a `diff` counterpart.
