import { PoolV3CoreConfigurator } from "@gearbox-protocol/sdk-gov/lib/state/poolV3Core";
import { PoolV3DeployConfig } from "@gearbox-protocol/sdk-gov/lib/state/poolV3DeployConfig";

const USDC_DECIMALS = BigInt(1e6);

export const config: PoolV3DeployConfig = {
  id: "mainnet-usdc-mt-v3",
  symbol: "dUSDCV3",
  name: "Diesel USDC V3 pool",
  network: "Mainnet",
  underlying: "USDC",
  accountAmount: BigInt(1_000_000) * USDC_DECIMALS,
  withdrawalFee: 0,
  expectedLiquidityLimit: BigInt(0),
  irm: {
    U1: 8000,
    U2: 9000,
    Rbase: 0,
    Rslope1: 100,
    Rslope2: 1000,
    Rslope3: 10000,
    isBorrowingMoreU2Forbidden: true,
  },
  ratesAndLimits: {
    CVX: {
      minRate: 10,
      maxRate: 300,
      quotaIncreaseFee: 0,
      limit: BigInt(5000000000000),
    },
    FXS: {
      minRate: 10,
      maxRate: 300,
      quotaIncreaseFee: 0,
      limit: BigInt(5000000000000),
    },
    LQTY: {
      minRate: 10,
      maxRate: 300,
      quotaIncreaseFee: 0,
      limit: BigInt(5000000000000),
    },
  },
  creditManagers: [
    {
      degenNft: false,
      expirationDate: undefined,
      minDebt: BigInt(1e5) * BigInt(1e6),
      maxDebt: BigInt(1e6) * BigInt(1e6),
      poolLimit: BigInt(0),
      collateralTokens: [
        {
          token: "CVX",
          lt: 2500,
        },
        {
          token: "FXS",
          lt: 2000,
        },
      ],
      adapters: ["UNISWAP_V3_ROUTER"],
    },
  ],
  supportsQuotas: false,
};

const poolCfg = PoolV3CoreConfigurator.new(config);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
