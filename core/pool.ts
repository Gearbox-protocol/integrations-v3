import { NormalToken, SupportedContract } from "@gearbox-protocol/sdk";
import { BalancerLPToken } from "@gearbox-protocol/sdk/lib/tokens/balancer";
import { BigNumberish } from "ethers";

import { CollateralTokenSymbol } from "./creditFilter";

export interface BalancerPoolConfig {
  pool: BalancerLPToken;
  status: string;
}

export interface UniswapV2PairConfig {
  token0: NormalToken;
  token1: NormalToken;
}

export interface UniswapV3PoolConfig {
  token0: NormalToken;
  token1: NormalToken;
  fee: 100 | 500 | 3000 | 10000;
}

export interface CreditConfigLive {
  minAmount: BigNumberish;
  maxAmount: BigNumberish;
  collateralTokens: Array<CollateralTokenSymbol>;
  adapters: Array<SupportedContract>;
  balancerPools?: Array<BalancerPoolConfig>;
  uniV2Pairs?: Array<UniswapV2PairConfig>;
  uniV3Pools?: Array<UniswapV3PoolConfig>;
  sushiswapPairs?: Array<UniswapV2PairConfig>;
}

export interface CMConfig extends CreditConfigLive {
  symbol: NormalToken;
}
