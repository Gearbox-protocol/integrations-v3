import { WAD } from "@gearbox-protocol/sdk";
import { BigNumber } from "ethers";

import { PoolConfig } from "../core/pool";

export const mainnetPools: Array<PoolConfig> = [
  {
    symbol: "WETH",
    U_optimal: 8000,
    U_reserve: 9000,
    R_base: 0,
    R_slope1: 250,
    R_slope2: 2000,
    R_slope3: 10000,
    expectedLiquidityLimit: WAD.mul(30000),
    supportsQuotas: true,
    quotedTokens: [
      { symbol: "STETH", minRate: 10, maxRate: 300, totalLimit: WAD.mul(3000) },
      {
        symbol: "stkcvxsteCRV",
        minRate: 50,
        maxRate: 1000,
        totalLimit: WAD.mul(3000),
      },
    ],
  },
  {
    symbol: "DAI",
    U_optimal: 8000,
    U_reserve: 9000,
    R_base: 0,
    R_slope1: 100,
    R_slope2: 1000,
    R_slope3: 10000,
    expectedLiquidityLimit: WAD.mul(50_000_000),
    supportsQuotas: true,
    quotedTokens: [
      {
        symbol: "stkcvxcrvPlain3andSUSD",
        minRate: 10,
        maxRate: 300,
        totalLimit: WAD.mul(3_000_000),
      },
    ],
  },
];
