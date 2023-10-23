import { PoolV3DeployConfig } from "@gearbox-protocol/sdk-gov";

const POOL_DECIMALS = BigInt(1e18);
const POOL_DIVIDER = BigInt(1800);

export const config: PoolV3DeployConfig = {
  id: "mainnet-weth-mt-v3",
  symbol: "dWETHV3",
  name: "WETH v3",
  network: "Mainnet",
  underlying: "WETH",
  accountAmount: BigInt(1_000_000) * POOL_DECIMALS,
  withdrawalFee: 0,
  expectedLiquidityLimit: (BigInt(30_000_000) / POOL_DIVIDER) * POOL_DECIMALS,
  irm: {
    U1: 7000,
    U2: 9000,
    Rbase: 0,
    Rslope1: 100,
    Rslope2: 200,
    Rslope3: 10000,
    isBorrowingMoreU2Forbidden: true,
  },
  ratesAndLimits: {
    USDC: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 1,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    DAI: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 1,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvUSDC: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 1,
      limit: (BigInt(10e6) * POOL_DECIMALS) / POOL_DIVIDER,
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
      name: "Trade WETH SmartShort v3",
      degenNft: false,
      expirationDate: undefined,
      minDebt: (BigInt(1e4) * POOL_DECIMALS) / POOL_DIVIDER,
      maxDebt: (BigInt(2e6) * POOL_DECIMALS) / POOL_DIVIDER,
      poolLimit: (BigInt(30_000_000) / POOL_DIVIDER) * POOL_DECIMALS,
      collateralTokens: [
        {
          token: "USDC",
          lt: 8700,
        },
        {
          token: "DAI",
          lt: 8700,
        },
        {
          token: "yvUSDC",
          lt: 8700,
        },
        {
          token: "sDAI",
          lt: 8700,
        },
      ],
      adapters: [
        {
          contract: "UNISWAP_V3_ROUTER",
          allowed: [
            { token0: "USDC", token1: "WETH", fee: 500 },
            { token0: "DAI", token1: "USDC", fee: 100 },
            { token0: "DAI", token1: "WETH", fee: 3000 },
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
