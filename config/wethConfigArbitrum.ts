import {
  BalancerVaultConfig,
  CreditManagerV3DeployConfig,
  PoolV3DeployConfig,
  UniV2Config,
  UniV3Config,
  VelodromeV2Config,
} from "@gearbox-protocol/sdk-gov";

const POOL_DECIMALS = BigInt(1e18);

const tier1UniV3Config: UniV3Config = {
  contract: "UNISWAP_V3_ROUTER",
  allowed: [
    { token0: "WETH", token1: "USDC_e", fee: 500 },
    { token0: "WETH", token1: "USDC", fee: 500 },
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
      pool: "wstETH_rETH_cbETH",
      status: 2,
    },
  ],
};

const tier1CreditManager: CreditManagerV3DeployConfig = {
  name: "Trade WETH Tier 1 Arbitrum",
  degenNft: false,
  expirationDate: undefined,
  minDebt: BigInt(1) * POOL_DECIMALS,
  maxDebt: BigInt(150) * POOL_DECIMALS,
  feeInterest: 2500,
  feeLiquidation: 50,
  liquidationPremium: 100,
  feeLiquidationExpired: 50,
  liquidationPremiumExpired: 100,
  poolLimit: BigInt(1000) * POOL_DECIMALS,
  collateralTokens: [
    {
      token: "USDC_e",
      lt: 9600,
    },
    {
      token: "USDC",
      lt: 9600,
    },
    {
      token: "WBTC",
      lt: 9400,
    },
    {
      token: "ARB",
      lt: 9000,
    },
    // FARMS
    {
      token: "wstETH",
      lt: 9600,
    },
    {
      token: "rETH",
      lt: 9600,
    },
    {
      token: "cbETH",
      lt: 9600,
    },
  ],
  adapters: [tier1UniV3Config, tier1BalancerConfig],
};

const tier2UniV3Config: UniV3Config = {
  contract: "UNISWAP_V3_ROUTER",
  allowed: [
    { token0: "PENDLE", token1: "WETH", fee: 3000 },
    { token0: "GMX", token1: "WETH", fee: 3000 },
    { token0: "LINK", token1: "WETH", fee: 3000 },
  ],
};

const tier2CreditManager: CreditManagerV3DeployConfig = {
  name: "Trade WETH Tier 2 Arbitrum",
  degenNft: false,
  expirationDate: undefined,
  minDebt: BigInt(1) * POOL_DECIMALS,
  maxDebt: BigInt(35) * POOL_DECIMALS,
  feeInterest: 2500,
  feeLiquidation: 100,
  liquidationPremium: 200,
  feeLiquidationExpired: 100,
  liquidationPremiumExpired: 200,
  poolLimit: BigInt(500) * POOL_DECIMALS,
  collateralTokens: [
    {
      token: "PENDLE",
      lt: 8000,
    },
    {
      token: "GMX",
      lt: 8350,
    },
    {
      token: "LINK",
      lt: 9000,
    },
  ],
  adapters: [tier2UniV3Config],
};

export const config: PoolV3DeployConfig = {
  id: "arbitrum-weth-v3",
  symbol: "dWETHV3",
  name: "WETH v3",
  network: "Arbitrum",
  underlying: "WETH",
  accountAmount: BigInt(10) * POOL_DECIMALS,
  withdrawalFee: 0,
  totalDebtLimit: BigInt(150_000) * POOL_DECIMALS,
  irm: {
    U1: 7000,
    U2: 9000,
    Rbase: 0,
    Rslope1: 200,
    Rslope2: 250,
    Rslope3: 6000,
    isBorrowingMoreU2Forbidden: true,
  },
  ratesAndLimits: {
    // TRADEABLE TOKENS
    USDC_e: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: BigInt(1500) * POOL_DECIMALS,
    },
    USDC: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: BigInt(2000) * POOL_DECIMALS,
    },
    WBTC: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: BigInt(3500) * POOL_DECIMALS,
    },
    ARB: {
      minRate: 4,
      maxRate: 2400,
      quotaIncreaseFee: 5,
      limit: BigInt(1300) * POOL_DECIMALS,
    },
    PENDLE: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 5,
      limit: BigInt(150) * POOL_DECIMALS,
    },
    GMX: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 5,
      limit: BigInt(150) * POOL_DECIMALS,
    },
    LINK: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 5,
      limit: BigInt(150) * POOL_DECIMALS,
    },
    // FARMS
    wstETH: {
      minRate: 1,
      maxRate: 350,
      quotaIncreaseFee: 0,
      limit: BigInt(3500) * POOL_DECIMALS,
    },
    rETH: {
      minRate: 1,
      maxRate: 350,
      quotaIncreaseFee: 0,
      limit: BigInt(3500) * POOL_DECIMALS,
    },
    cbETH: {
      minRate: 1,
      maxRate: 350,
      quotaIncreaseFee: 0,
      limit: BigInt(2500) * POOL_DECIMALS,
    },
    sfrxETH: {
      minRate: 1,
      maxRate: 350,
      quotaIncreaseFee: 0,
      limit: BigInt(2500) * POOL_DECIMALS,
    },
  },
  creditManagers: [tier1CreditManager, tier2CreditManager],
  supportsQuotas: true,
};
