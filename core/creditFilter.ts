import { SupportedToken } from "@gearbox-protocol/sdk-gov";

export interface AllowedToken {
  address: string;
  liquidationThreshold: number;
}

export interface CollateralTokenSymbol {
  symbol: SupportedToken;
  liquidationThreshold: number;
}
