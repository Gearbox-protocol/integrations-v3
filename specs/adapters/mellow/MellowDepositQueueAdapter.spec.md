# Mellow Deposit Queue Adapter

## Contract overview

This contract is an adapter that allows Gearbox CAs to interact with the Mellow Flexible Vault deposit queue, in order to deposit a specific asset into a Mellow flexible vault.

The adapter has a gateway as its target, which enables safely collateralizing pending deposits in order to enter Mellow vaults with leverage. The gateway also enables some additional functions, such as partial deposit claiming.

## Protocol overivew

Mellow is an LRT protocol that allows curators to create vaults for ETH or ETH-based derivatives, where users can deposit their ETH for additional yield.

Mellow's deposit queue allows users to deposit into a vault. The deposit is delayed due to Mellow's internal mechanics. The user first needs to initiate a deposit with `deposit`, which will transfer the deposited asset from the user to the vault. Then the deposit matures based on the vault's deposit interval + 1 day. It is then claimable with `claim`, which will mint vault shares to the user. Deposits can also be cancelled until they mature with `cancelDepositRequest`, which will transfer the deposited assets back.

## Contract features

MellowDepositQueueAdapter allows user to request deposits via the gateway, and then claim them once they mature.

In order to request withdrawals, users can call `deposit` or `depositDiff`, in order to claim them, users call `claim` with the required amount.

As withdrawals in the process of maturation are tracked via a phantom token, the adapter also has a `withdrawPhantomToken` as a standard phantom token unwrapping function - this function calls `claim` internally.
