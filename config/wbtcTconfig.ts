import { PoolV3DeployConfig } from "@gearbox-protocol/sdk-gov";

const POOL_DECIMALS = BigInt(1e8);
const POOL_DIVIDER = BigInt(26000);

export const config: PoolV3DeployConfig = {
  id: "mainnet-wbtc-mt-v3",
  symbol: "dWBTCV3",
  name: "Universal WBTC v3",
  network: "Mainnet",
  underlying: "WBTC",
  accountAmount: BigInt(1_000_000) * POOL_DECIMALS,
  withdrawalFee: 0,
  expectedLiquidityLimit: (BigInt(10_000_000) / POOL_DIVIDER) * POOL_DECIMALS,
  irm: {
    U1: 7000,
    U2: 9000,
    Rbase: 0,
    Rslope1: 100,
    Rslope2: 300,
    Rslope3: 10000,
    isBorrowingMoreU2Forbidden: true,
  },
  ratesAndLimits: {
    USDC: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 1,
      limit: (BigInt(10e6) / POOL_DIVIDER) * POOL_DECIMALS,
    },
    DAI: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 1,
      limit: (BigInt(10e6) / POOL_DIVIDER) * POOL_DECIMALS,
    },
    WETH: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 1,
      limit: (BigInt(10e6) / POOL_DIVIDER) * POOL_DECIMALS,
    },
    yvUSDC: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 1,
      limit: (BigInt(10e6) / POOL_DIVIDER) * POOL_DECIMALS,
    },
    sDAI: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 1,
      limit: (BigInt(10e6) / POOL_DIVIDER) * POOL_DECIMALS,
    },
  },
  creditManagers: [
    {
      name: "Trade WBTC SmartShort v3",
      degenNft: false,
      expirationDate: undefined,
      minDebt: (BigInt(1e4) * POOL_DECIMALS) / POOL_DIVIDER,
      maxDebt: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
      poolLimit: (BigInt(10_000_000) / POOL_DIVIDER) * POOL_DECIMALS,
      collateralTokens: [
        {
          token: "USDC",
          lt: 8700,
        },
        {
          token: "WETH",
          lt: 8700,
        },
        {
          token: "DAI",
          lt: 8700,
        },
        {
          token: "yvUSDC",
          lt: 8500,
        },
        {
          token: "sDAI",
          lt: 8500,
        },
      ],
      adapters: [
        {
          contract: "UNISWAP_V3_ROUTER",
          allowed: [
            { token0: "USDC", token1: "WETH", fee: 500 },
            { token0: "WBTC", token1: "WETH", fee: 3000 },
            { token0: "DAI", token1: "USDC", fee: 100 },
            { token0: "DAI", token1: "WETH", fee: 3000 },
            { token0: "WBTC", token1: "WETH", fee: 500 },
            { token0: "WBTC", token1: "USDC", fee: 3000 },
          ],
        },
        {
          contract: "YEARN_USDC_VAULT",
        },
        {
          contract: "MAKER_DSR_VAULT",
        },
      ],
    },
  ],
  supportsQuotas: true,
};
