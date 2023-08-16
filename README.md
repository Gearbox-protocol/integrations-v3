![gearbox](header.png)

## Gearbox protocol

Gearbox is a generalized leverage protocol. It has two sides to it: passive liquidity providers who earn low-risk APY by providing single-asset liquidity; and active farmers, firms, or even other protocols who borrow those assets to trade or farm with even x10 leverage.

Gearbox Protocol allows anyone to take DeFi-native leverage and then use it across various (DeFi & more) protocols in a composable way. You take leverage with Gearbox and then use it on other protocols you already love: Uniswap, Curve, Convex, Lido, etc. For example, you can leverage trade on Uniswap, leverage farm on Yearn, make delta-neutral strategies, get Leverage-as-a-Service for your structured product, and more... Thanks to the Credit Accounts primitive!

_Some compare composable leverage as a primitive to DeFi-native prime brokerage._

## Currently supported protocols

- Uniswap V2 (swaps only);
- Uniswap V3 (swaps only);
- Curve
- Convex
- Yearn
- Lido + wstETH

## Repository overview

This repository contains the smart contracts used to integrate third-party protocols with Gearbox, as well as relevant unit and live network tests.

```
- contracts
  - adapters
  - factories
  - integrations
  - interfaces
  - multicall
  - oracles
```

### Adapters

This directory contains code for third-party protocol adapters, as well as the required support contracts.

Adapters are contracts that implement the interfaces of their respective third-party protocol counterparts (possibly with additional helper functions).

Functions in adapters implement necessary logic to route a call to the counterpart function (function with the same signature in the original protocol) through a Gearbox Credit Manager, allowing Credit Account owners to use familiar interfaces to manage their accounts.

#### Convex

1. `ConvexV1_BaseRewardPool.sol`. Adapter for Convex farming pools, where Convex LP tokens can be staked to receive CRV, CVX, and possibly additional rewards.
2. `ConvexV1_Booster.sol`. Adapter for the Convex Booster contract, which can be used to wrap Curve LP tokens into Convex LP and stake them in Convex pools.
3. `ConvexV1_ClaimZap.sol`. A contract analogous to the Convex ClaimZap, allowing users to claim rewards from multiple pools with a single call.
4. `ConvexV1_StakedPositionToken.sol`. A contract implementing a phantom token, used to track amounts staked by users in Convex pools (since Convex does not mint tokens representing pool positions).

#### Curve

1. `CurveV1_Base.sol`. Generic adapter for Curve pools. Implements logic for swapping assets, adding liquidity (including adding liquidity in one coin), as well as several modes of removing liquidity (normal, one coin, imbalanced).
2. `CurveV1_2.sol`, `CurveV1_3.sol`, `CurveV1_4.sol`. Interface adapters that expose functions with parameters dependent on N_COINS (such as `add_liquidity` or `remove_liquidity`). Note that main logic for these functions is still contained in `CurveV1_Base.sol` as an internal function.
3. `CurveV1_DepositZap.sol`. Adapter for Curve deposit helper contracts. Required to support one-coin withdrawals for older Curve pools that don't have this functionality.
4. `CurveV1_stETH.sol`. Adapter for the Curve stETH pool. Since the stETH pool uses native ETH, the adapter needs to interact with a gateway to convert WETH to stETH. As such, there are some differences in functioning that require a separate adapter.
5. `CurveV1_stETHGateway.sol`. A gateway between the stETH pool adapter and the respective pool. Used to convert WETH to ETH (and back) as needed.

#### Lido

1. `LidoV1.sol`. Adapter for the Lido stETH contract, which allows users to submit ETH and mint stETH. Interacts with a gateway instead of the original Lido contract, to convert WETH into native ETH.
2. `LidoV1_WETHGateway.sol`. Gateway between the Lido adapter and the original contract, which converts WETH to native ETH before submitting for stETH.
3. `WstETHV1.sol`. Adapter for the wstETH contract, which allows users to wrap their stETH into a non-rebase token.
4. `WstETHGateway.sol`. Gateway for the Gearbox wstETH borrowing pool, which allows users to deposit stETH directly without pre-wrapping it.

#### Uniswap

1. `UniswapV2.sol`. Adapter for the Uniswap V2 router, which allows users to swap tokens to other tokens. Does not support native ETH swaps or liquidity provision.
2. `UniswapV3.sol`. Adapter for the Uniswap V3 router, which allows users to swap tokens to other tokens.

#### Yearn

1. `YearnV2.sol`. Adapter for Yearn vaults, which allows users to deposit tokens and accrue yield.

### Factories

Contains `CreditManagerV3Factory.sol`, which is an extension of `CreditManagerV3FactoryBase.sol` (from `core-v2`) with some additional adapter-specific configuration.

### Integrations

Contains interfaces for third-party contracts that adapters implement or otherwise use. Also has `TokenType.sol`, which is an enum used system-wide to determine types of assets.

### Multicall

Contains helper libraries that construct Gearbox-compatible multicalls with a convenient interface. Multicall libraries are implemented for all supported adapters.

### Oracles

Contains price feed contracts for non-standard asset classes supported by Gearbox.

#### Curve

Contains price feeds for Curve 2-,3- and 4-asset pool LP tokens. For more information on price feed implementation, see [documentation](https://dev.gearbox.fi/docs/documentation/oracle/curve-pricefeed).

#### Lido

Contains the price feed for wstETH, which computes the price based on stETH price and wstETH contract's withdrawal rate. Similar to Yearn price feed, see [documentation](https://dev.gearbox.fi/docs/documentation/oracle/yearn-pricefeed) for more information.

#### Yearn

Contains a price feed for Yearn vault shares. For more information on price feed implementation, see [documentation](https://dev.gearbox.fi/docs/documentation/oracle/yearn-pricefeed).

## Using contracts

Source contracts and their respective interfaces can be imported from an npm package `@gearbox-protocol/integrations-v2`, e.g.:

```=solidity
import {ICreditFacadeV3, MultiCall} from '@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacadeV3.sol';
import {YearnV2_Multicaller, YearnV2_Calls} from '@gearbox-protocol/integrations-v2/multicall/yearn/YearnV2_Calls.sol';

contract MyContract {
  using YearnV2_Calls for YearnV2_Multicaller;

  ICreditFacadeV3 creditFacade;

  function withdraw(address vaultAdapter) {
     MultiCall[] memory calls = new MultiCall[](1);
     calls[0] = YearnV2_Multicaller(vaultAdapter).withdraw();
     creditFacade.multicall(calls);
  }
}
```

## Bug bounty

This repository is subject to the Gearbox bug bounty program, per the terms defined [here](https://docs.gearbox.finance/risk-and-security/audits-bug-bounty#bug-bounty).

## Documentation

General documentation of the Gearbox Protocol can be found [here](https://docs.gearbox.fi). Developer documentation with
more tech-related infromation about the protocol, contract interfaces, integration guides and audits is available on the
[Gearbox dev protal](https://dev.gearbox.fi).

## Testing

### Setup

Running Forge tests requires Foundry. See [Foundry Book](https://book.getfoundry.sh/getting-started/installation) for installation details.

### Unit tests

`forge t`

### Live network integration tests

1. Start a Mainnet or Goerli fork with: `yarn fork` or `yarn fork-goerli`, respectively.
2. Open a new terminal window and run `forge t --match-test _live_ --fork-url http://localhost:8545`.

It is recommended to set `$ETH_MAINNET_BLOCK` or `$ETH_GOERLI_BLOCK` to run the tests on a fixed block. Live tests can take significant time to run and can fail unexpectedly due to external provider errors. Re-running the tests on the same block (or without restarting the fork) will be sped up due to caching.

## Licensing

The primary license for the Gearbox-protocol/integrations-v2 is the Business Source License 1.1 (BUSL-1.1), see [LICENSE](https://github.com/Gearbox-protocol/integrations-v2/blob/master/LICENSE). The files which are NOT licensed under the BUSL-1.1 have appropriate SPDX headers.

## Disclaimer

This application is provided "as is" and "with all faults." Me as developer makes no representations or
warranties of any kind concerning the safety, suitability, lack of viruses, inaccuracies, typographical
errors, or other harmful components of this software. There are inherent dangers in the use of any software,
and you are solely responsible for determining whether this software product is compatible with your equipment and
other software installed on your equipment. You are also solely responsible for the protection of your equipment
and backup of your data, and THE PROVIDER will not be liable for any damages you may suffer in connection with using,
modifying, or distributing this software product.

### Important information for contributors

As a contributor to the Gearbox Protocol GitHub repository, your pull requests indicate acceptance of our Gearbox Contribution Agreement. This agreement outlines that you assign the Intellectual Property Rights of your contributions to the Gearbox Foundation. This helps safeguard the Gearbox protocol and ensure the accumulation of its intellectual property. Contributions become part of the repository and may be used for various purposes, including commercial. As recognition for your expertise and work, you receive the opportunity to participate in the protocol's development and the potential to see your work integrated within it. The full Gearbox Contribution Agreement is accessible within the [repository](/ContributionAgreement) for comprehensive understanding. [Let's innovate together!]
