import { NormalToken, SupportedContract } from "@gearbox-protocol/sdk";
import { BalancerLPToken } from "@gearbox-protocol/sdk/lib/tokens/balancer";
import { BigNumberish } from "ethers";

import { CollateralTokenSymbol } from "./creditFilter";

export interface BalancerPoolConfig {
  pool: BalancerLPToken;
  status: string;
}

export interface CreditConfigLive {
  minAmount: BigNumberish;
  maxAmount: BigNumberish;
  collateralTokens: Array<CollateralTokenSymbol>;
  adapters: Array<SupportedContract>;
  balancerPools?: Array<BalancerPoolConfig>;
}

export interface CMConfig extends CreditConfigLive {
  symbol: NormalToken;
}
