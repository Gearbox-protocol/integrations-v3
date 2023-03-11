import {
  NormalToken,
  SupportedContract,
  SupportedToken,
} from "@gearbox-protocol/sdk";
import { BigNumberish } from "ethers";

import { CollateralTokenSymbol } from "./creditFilter";

export interface CreditConfigLive {
  minAmount: BigNumberish;
  maxAmount: BigNumberish;
  collateralTokens: Array<CollateralTokenSymbol>;
  adapters: Array<SupportedContract>;
}

export interface CMConfig extends CreditConfigLive {
  symbol: NormalToken;
}

export interface QuotedTokenParams {
  symbol: SupportedToken;
  minRate: BigNumberish;
  maxRate: BigNumberish;
  totalLimit: BigNumberish;
}

export interface InterestRateModelParams {
  U_optimal: BigNumberish;
  U_reserve: BigNumberish;
  R_base: BigNumberish;
  R_slope1: BigNumberish;
  R_slope2: BigNumberish;
  R_slope3: BigNumberish;
}

export interface PoolConfig extends InterestRateModelParams {
  symbol: NormalToken;
  expectedLiquidityLimit: BigNumberish;
  supportsQuotas: boolean;
  quotedTokens: Array<QuotedTokenParams>;
}
