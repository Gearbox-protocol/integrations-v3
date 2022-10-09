import { NormalToken, SupportedContract } from "@gearbox-protocol/sdk";
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
