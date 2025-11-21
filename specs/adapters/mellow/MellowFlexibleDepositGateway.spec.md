# Mellow Flexible Deposit Gateway

## Contract overview

This contract acts as an intermediary between the adapter and the Mellow Deposit Queue, in order to facilitate delayed deposits for Gearbox CAs. There are several elements that enable collateralizing deposits:

- The gateway itself, which acts as an entry point for CAs
- `MellowFlexibleDepositor`, which is a disposable account created for each CA and actually requests / claims deposits. Since most protocols with delayed deposits / withdrawals track relevant data by address, having a separate account for each CA greatly simplifies deposit tracking logic, while still leaving space for adding more functionality to the process.
- `MellowFlexibleDepositPhantomToken`, which is a phantom token that tracks deposits in progress and allows using them as collateral. The balance of the phantom token is the sum of pending and claimable deposits, which are computed in `MellowFlexibleDepositor`.

## Protocol overview

Mellow is an LRT protocol that allows curators to create vaults for ETH or ETH-based derivatives, where users can deposit their ETH for additional yield.

Mellow's deposit queue allows users to deposit into a vault. The deposit is delayed due to Mellow's internal mechanics. The user first needs to initiate a deposit with `deposit`, which will transfer the deposited asset from the user to the vault. Then the deposit matures based on the vault's deposit interval + 1 day. It is then claimable with `claim`, which will mint vault shares to the user. Deposits can also be cancelled until they mature with `cancelDepositRequest`, which will transfer the deposited assets back. The deposit queue only allows 1 pending deposit to be active at given time.

## Contract features

### MellowFlexibleDepositGateway

MellowFlexibleDepositGateway allows users to initiate and claim deposits via `deposit` and `claim`. These functions fetch the `MellowFlexibleDepositor` address associated with the calling CA (or create a new one), and call the respective functions in them (with the actual business logic mostly contained in `MellowFlexibleDepositor` itself). The gateway also exposes `getPendingAssets` and `getClaimableShares`, which are used by the phantom token to compute total outstanding deposit value in vault share terms.

### MellowFlexibleDepositor

MellowFlexibleDepositor is created for each CA and initiates / completes deposits on behalf of this CA. Respective state-changing functions (such as `deposit` / `claim`) are gateway-only, so that the gateway is the sole entry-point for CAs.

For `deposit`, the contract assumes that the deposited asset is already transferred to it, so it only approves funds to the deposit queue and requests a deposit. To avoid any unexpected side effects, the depositor does not allow creating a new deposit if there is one pending.

For `claim`, the contract computes the amount of matured deposits already on the contract (if they were previously partially claimed), and the amount of the matured deposit that is not yet claimed, if present. The contract then claims the deposit still in the deposit queue. Then, the depositor sends the required amount to the account.

The depositor also provides `getPendingAssets` and `getClaimableShares`, to retrieve the amount of pending assets in the deposit, and the amount of claimable (but not pending) shares.

### MellowFlexibleDepositPhantomToken

The phantom token tracks deposits-in-progress in its balance in order for them to be usable as collateral. The balance represents the expected amount of shares and is computed as the sum of pending assets multiplied by the asset-to-share rate, and the claimable shares.
