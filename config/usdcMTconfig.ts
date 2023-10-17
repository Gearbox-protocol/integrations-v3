import { PoolV3DeployConfig } from "@gearbox-protocol/sdk-gov";

const POOL_DECIMALS = BigInt(1e6);
const POOL_DIVIDER = BigInt(1);

export const config: PoolV3DeployConfig = {
  id: "mainnet-usdc-mt-v3",
  symbol: "dUSDCV3",
  name: "Trade USDC v3",
  network: "Mainnet",
  underlying: "USDC",
  accountAmount: BigInt(1_000_000) * POOL_DECIMALS,
  withdrawalFee: 0,
  expectedLiquidityLimit: BigInt(0),
  irm: {
    U1: 7000,
    U2: 9000,
    Rbase: 0,
    Rslope1: 150,
    Rslope2: 400,
    Rslope3: 10000,
    isBorrowingMoreU2Forbidden: true,
  },
  ratesAndLimits: {
    MKR: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    UNI: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 200,
      limit: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    LINK: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 200,
      limit: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    LDO: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 200,
      limit: (BigInt(5e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    RPL: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 200,
      limit: (BigInt(3e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    CRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 200,
      limit: (BigInt(25e4) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    APE: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(3e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    CVX: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(3e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    FXS: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(3e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
  },
  creditManagers: [
    {
      name: "Trade USDC v3",
      degenNft: false,
      expirationDate: undefined,
      minDebt: (BigInt(1e4) * POOL_DECIMALS) / POOL_DIVIDER,
      maxDebt: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
      poolLimit: (BigInt(20_000_000) * POOL_DECIMALS) / POOL_DIVIDER,
      collateralTokens: [
        {
          token: "WETH",
          lt: 8700,
        },
        {
          token: "WBTC",
          lt: 8700,
        },
        {
          token: "MKR",
          lt: 8500,
        },
        {
          token: "UNI",
          lt: 8500,
        },
        {
          token: "LINK",
          lt: 8500,
        },
        {
          token: "LDO",
          lt: 8500,
        },
        {
          token: "RPL",
          lt: 8500,
        },
        {
          token: "CRV",
          lt: 8500,
        },
        {
          token: "APE",
          lt: 8500,
        },
        {
          token: "CVX",
          lt: 8500,
        },
        {
          token: "FXS",
          lt: 8500,
        },
      ],
      adapters: [{ contract: "UNISWAP_V3_ROUTER" }],
    },
  ],
  supportsQuotas: false,
};
