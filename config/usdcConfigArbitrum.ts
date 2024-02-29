import {
  BalancerVaultConfig,
  CreditManagerV3DeployConfig,
  PoolV3DeployConfig,
  UniV3Config,
} from "@gearbox-protocol/sdk-gov";

const POOL_DECIMALS = BigInt(1e6);
const POOL_DIVIDER = BigInt(1);

const tier1UniV3Config: UniV3Config = {
  contract: "UNISWAP_V3_ROUTER",
  allowed: [
    { token0: "WETH", token1: "USDC_e", fee: 500 },
    { token0: "WETH", token1: "WBTC", fee: 500 },
    { token0: "WETH", token1: "ARB", fee: 500 },
    { token0: "WETH", token1: "ARB", fee: 3000 },
    { token0: "wstETH", token1: "WETH", fee: 100 },
    { token0: "ARB", token1: "USDC_e", fee: 500 },
    { token0: "WBTC", token1: "WETH", fee: 3000 },
  ],
};

const tier1BalancerConfig: BalancerVaultConfig = {
  contract: "BALANCER_VAULT",
  allowed: [
    {
      pool: "wstETH_WETH_BPT",
      status: 2,
    },
    {
      pool: "rETH_WETH_BPT",
      status: 2,
    },
    {
      pool: "wstETH_rETH_sfrxETH",
      status: 2,
    },
    {
      pool: "wstETH_rETH_cbETH",
      status: 2,
    },
  ],
};

const tier1CreditManager: CreditManagerV3DeployConfig = {
  name: "Trade USDC.e Tier 1 Arbitrum",
  degenNft: false,
  expirationDate: undefined,
  minDebt: (BigInt(1e3) * POOL_DECIMALS) / POOL_DIVIDER,
  maxDebt: (BigInt(4e5) * POOL_DECIMALS) / POOL_DIVIDER,
  feeInterest: 2500,
  feeLiquidation: 50,
  liquidationPremium: 100,
  feeLiquidationExpired: 50,
  liquidationPremiumExpired: 100,
  poolLimit: (BigInt(4e6) * POOL_DECIMALS) / POOL_DIVIDER,
  collateralTokens: [
    {
      token: "WETH",
      lt: 9400,
    },
    {
      token: "WBTC",
      lt: 9400,
    },
    {
      token: "ARB",
      lt: 9000,
    },
    // BOOSTED
    {
      token: "wstETH",
      lt: 9400,
    },
    {
      token: "rETH",
      lt: 9400,
    },
    {
      token: "cbETH",
      lt: 9400,
    },
  ],
  adapters: [tier1UniV3Config, tier1BalancerConfig],
};

const tier2UniV3Config: UniV3Config = {
  contract: "UNISWAP_V3_ROUTER",
  allowed: [
    { token0: "WETH", token1: "USDC_e", fee: 500 },
    { token0: "PENDLE", token1: "WETH", fee: 3000 },
    { token0: "GMX", token1: "WETH", fee: 3000 },
    { token0: "LINK", token1: "WETH", fee: 3000 },
  ],
};

const tier2CreditManager: CreditManagerV3DeployConfig = {
  name: "Trade USDC.e Tier 2 Arbitrum",
  degenNft: false,
  expirationDate: undefined,
  minDebt: (BigInt(1e3) * POOL_DECIMALS) / POOL_DIVIDER,
  maxDebt: (BigInt(1e5) * POOL_DECIMALS) / POOL_DIVIDER,
  feeInterest: 2500,
  feeLiquidation: 100,
  liquidationPremium: 200,
  feeLiquidationExpired: 100,
  liquidationPremiumExpired: 200,
  poolLimit: (BigInt(2e6) * POOL_DECIMALS) / POOL_DIVIDER,
  collateralTokens: [
    {
      token: "WETH",
      lt: 9400,
    },
    {
      token: "GMX",
      lt: 8350,
    },
    {
      token: "LINK",
      lt: 9000,
    },
    {
      token: "PENDLE",
      lt: 8000,
    },
  ],
  adapters: [tier2UniV3Config],
};

export const config: PoolV3DeployConfig = {
  id: "arbitrum-usdc-v3",
  symbol: "dUSDCV3",
  name: "Main USDC.e v3",
  network: "Arbitrum",
  underlying: "USDC_e",
  accountAmount: BigInt(10_000) * POOL_DECIMALS,
  withdrawalFee: 0,
  totalDebtLimit: BigInt(100_000_000) * POOL_DECIMALS,
  irm: {
    U1: 7000,
    U2: 9000,
    Rbase: 0,
    Rslope1: 100,
    Rslope2: 125,
    Rslope3: 10000,
    isBorrowingMoreU2Forbidden: true,
  },
  ratesAndLimits: {
    // TRADEABLE TOKENS
    WBTC: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: (BigInt(4.5e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    WETH: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: (BigInt(7e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    ARB: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 5,
      limit: (BigInt(3e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    GMX: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 5,
      limit: (BigInt(5e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    LINK: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 5,
      limit: (BigInt(5e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    PENDLE: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 5,
      limit: (BigInt(5e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    // BOOSTED
    wstETH: {
      minRate: 4,
      maxRate: 1500,
      quotaIncreaseFee: 1,
      limit: (BigInt(7e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    rETH: {
      minRate: 4,
      maxRate: 1500,
      quotaIncreaseFee: 1,
      limit: (BigInt(7e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    cbETH: {
      minRate: 4,
      maxRate: 1500,
      quotaIncreaseFee: 1,
      limit: (BigInt(7e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
  },
  creditManagers: [tier1CreditManager, tier2CreditManager],
  supportsQuotas: true,
};
