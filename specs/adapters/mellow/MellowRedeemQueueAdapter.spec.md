# Mellow Redeem Queue Adapter

## Contract overview

This contract is an adapter that allows Gearbox CAs to interact with the Mellow Flexible Vault redemption queue, in order to withdraw a specific asset from a Mellow flexible vault.

The adapter has a gateway as its target, which enables safely collateralizing pending redemptions in order to enter Mellow vaults with leverage. The gateway also enables some additional functions, such as partial redemption claims.

## Protocol overivew

Mellow is an LRT protocol that allows curators to create vaults for ETH or ETH-based derivatives, where users can deposit their ETH for additional yield.

Mellow's redemption queue allows users to withdraw from a vault. The redemption is delayed due to Mellow's internal mechanics. The user first needs to initiate a withdrawal with `redeem`, which will burn vault shares from the CA. Then the redemption matures based on the vault's redemption interval + 1 day. It is then claimable with `claim`, which will transfer the asset to the user.

## Contract features

MellowRedeemQueueAdapter allows a user to request redemptions via the gateway, and then claim them once they mature.

In order to request withdrawals, users can call `redeem` or `redeemDiff`, in order to claim them, users call `claim` with the required amount.

As redemptions in the process of maturation are tracked via a phantom token, the adapter also has a `withdrawPhantomToken` as a standard phantom token unwrapping function - this function calls `claim` internally.
