# Mellow Flexible Redeem Gateway

## Contract overview

This contract acts as an intermediary between the adapter and the Mellow Redeem Queue, in order to facilitate delayed redemptions for Gearbox CAs. There are several elements that enable collateralizing redemptions:

- The gateway itself, which acts as an entry point for CAs
- `MellowFlexibleRedeemer`, which is a disposable account created for each CA and actually requests / claims redemptions. Since most protocols with delayed redemptions track relevant data by address, having a separate account for each CA greatly simplifies redemption tracking logic, while still leaving space for adding more functionality to the process.
- `MellowFlexibleRedeemPhantomToken`, which is a phantom token that tracks redemptions in progress and allows using them as collateral. The balance of the phantom token is the sum of pending and claimable redemptions, which are computed in `MellowFlexibleRedeemer`.

## Protocol overview

Mellow is an LRT protocol that allows curators to create vaults for ETH or ETH-based derivatives, where users can deposit their ETH for additional yield.

Mellow's redemption queue allows users to withdraw from a vault. The redemption is delayed due to Mellow's internal mechanics. The user first needs to initiate a withdrawal with `redeem`, which will burn vault shares from the CA. Then the redemption matures based on the vault's redemption interval + 1 day. It is then claimable with `claim`, which will transfer the asset to the user.

## Contract features

### MellowFlexibleRedeemGateway

MellowFlexibleRedeemGateway allows users to initiate and claim redemptions via `redeem` and `claim`. These functions fetch the `MellowFlexibleRedeemer` address associated with the calling CA (or create a new one), and call the respective functions in them (with the actual business logic mostly contained in `MellowFlexibleRedeemer` itself). The gateway also exposes `getPendingShares` and `getClaimableAssets`, which are used by the phantom token to compute total outstanding redemption value in withdrawn asset terms.

### MellowFlexibleRedeemer

MellowFlexibleDepositor is created for each CA and initiates / completes redemptions on behalf of this CA. Respective state-changing functions (such as `redeem` / `claim`) are gateway-only, so that the gateway is the sole entry-point for CAs.

For `redeem`, the contract approves funds to the deposit queue and requests a deposit. To avoid any unexpected side effects, the depositor does not allow creating a new deposit if there is one pending. In order to limit the gas expense for `getPendingShares` / `getClaimableAssets`, the number of active redemptions is limited to 5.

For `claim`, the contract computes the amount of matured redemptions already on the contract (if they were previously partially claimed), and the amount of the matured redemptions that are not yet claimed, if present. The contract then claims the redemptions still in the queue. Then, the redeemer sends the required amount to the account.

The redeemer also provides `getPendingShares` and `getClaimableAssets`, to retrieve the amount of pending shares in all redemptions, and the amount of claimable (but not pending) assets.

### MellowFlexibleDepositPhantomToken

The phantom token tracks redemptions-in-progress in its balance in order for them to be usable as collateral. The balance represents the expected amount of assets from all redemptions and is computed as the sum of pending shares multiplied by the share-to-asset rate, and the claimable assets.
