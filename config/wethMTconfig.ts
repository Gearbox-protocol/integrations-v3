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
  expectedLiquidityLimit: BigInt(0),
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
    STETH: {
      minRate: 1,
      maxRate: 200,
      quotaIncreaseFee: 0,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    USDC: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 100,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
  },
  creditManagers: [
    {
      name: "WETH v3",
      degenNft: false,
      expirationDate: undefined,
      minDebt: (BigInt(1e4) * POOL_DECIMALS) / POOL_DIVIDER,
      maxDebt: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
      poolLimit: BigInt(0),
      collateralTokens: [
        {
          token: "WBTC",
          lt: 8700,
        },
        {
          token: "USDC",
          lt: 8700,
        },
      ],
      adapters: [{ contract: "UNISWAP_V3_ROUTER" }],
    },
  ],
  supportsQuotas: false,
};
