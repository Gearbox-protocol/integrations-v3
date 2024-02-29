import {
  BalancerVaultConfig,
  CreditManagerV3DeployConfig,
  PoolV3DeployConfig,
  UniV3Config,
  VelodromeV2Config,
} from "@gearbox-protocol/sdk-gov";

const POOL_DECIMALS = BigInt(1e18);
const POOL_DIVIDER = BigInt(2000);

const VELODROME_V2_DEFAULT_FACTORY =
  "0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a";

const tier1UniV3Config: UniV3Config = {
  contract: "UNISWAP_V3_ROUTER",
  allowed: [
    { token0: "WETH", token1: "OP", fee: 3000 },
    { token0: "WETH", token1: "USDC", fee: 500 },
    { token0: "WETH", token1: "USDC", fee: 3000 },
    { token0: "WETH", token1: "WBTC", fee: 3000 },
    { token0: "WETH", token1: "WBTC", fee: 500 },
    { token0: "OP", token1: "USDC", fee: 3000 },
    { token0: "WETH", token1: "OP", fee: 500 },
  ],
};

const tier1BalancerConfig: BalancerVaultConfig = {
  contract: "BALANCER_VAULT",
  allowed: [
    {
      pool: "BPT_ROAD",
      status: 2,
    },
  ],
};

const tier1VelodromeConfig: VelodromeV2Config = {
  contract: "VELODROME_V2_ROUTER",
  allowed: [
    {
      token0: "WETH",
      token1: "OP",
      stable: false,
      factory: VELODROME_V2_DEFAULT_FACTORY,
    },
    {
      token0: "OP",
      token1: "USDC",
      stable: false,
      factory: VELODROME_V2_DEFAULT_FACTORY,
    },
    {
      token0: "WETH",
      token1: "USDC",
      stable: false,
      factory: VELODROME_V2_DEFAULT_FACTORY,
    },
  ],
};

const tier1CreditManager: CreditManagerV3DeployConfig = {
  name: "Trade WETH Tier 1 Optimism",
  degenNft: false,
  expirationDate: undefined,
  minDebt: (BigInt(1e3) * POOL_DECIMALS) / POOL_DIVIDER,
  maxDebt: (BigInt(2e5) * POOL_DECIMALS) / POOL_DIVIDER,
  feeInterest: 2500,
  feeLiquidation: 50,
  liquidationPremium: 100,
  feeLiquidationExpired: 50,
  liquidationPremiumExpired: 100,
  poolLimit: (BigInt(2e6) * POOL_DECIMALS) / POOL_DIVIDER,
  collateralTokens: [
    {
      token: "USDC",
      lt: 9600,
    },
    {
      token: "WBTC",
      lt: 9600,
    },
    {
      token: "OP",
      lt: 9600,
    },
    // BOOSTED
    {
      token: "yvUSDC",
      lt: 9400,
    },
    {
      token: "yvOP",
      lt: 9400,
    },
  ],
  adapters: [
    tier1UniV3Config,
    tier1BalancerConfig,
    tier1VelodromeConfig,
    { contract: "YEARN_USDC_VAULT" },
    { contract: "YEARN_OP_VAULT" },
  ],
};

const tier2UniV3Config: UniV3Config = {
  contract: "UNISWAP_V3_ROUTER",
  allowed: [
    { token0: "WETH", token1: "USDC", fee: 500 },
    { token0: "WETH", token1: "USDC", fee: 3000 },
    { token0: "USDC", token1: "WLD", fee: 10000 },
    { token0: "WETH", token1: "LINK", fee: 3000 },
    { token0: "WETH", token1: "SNX", fee: 3000 },
  ],
};

const tier2VelodromeConfig: VelodromeV2Config = {
  contract: "VELODROME_V2_ROUTER",
  allowed: [
    {
      token0: "WETH",
      token1: "USDC",
      stable: false,
      factory: VELODROME_V2_DEFAULT_FACTORY,
    },
    {
      token0: "USDC",
      token1: "SNX",
      stable: false,
      factory: VELODROME_V2_DEFAULT_FACTORY,
    },
  ],
};

const tier2CreditManager: CreditManagerV3DeployConfig = {
  name: "Trade WETH Tier 2 Optimism",
  degenNft: false,
  expirationDate: undefined,
  minDebt: (BigInt(1e3) * POOL_DECIMALS) / POOL_DIVIDER,
  maxDebt: (BigInt(5e4) * POOL_DECIMALS) / POOL_DIVIDER,
  feeInterest: 2500,
  feeLiquidation: 100,
  liquidationPremium: 200,
  feeLiquidationExpired: 100,
  liquidationPremiumExpired: 200,
  poolLimit: (BigInt(5e5) * POOL_DECIMALS) / POOL_DIVIDER,
  collateralTokens: [
    {
      token: "USDC",
      lt: 9500,
    },
    {
      token: "WLD",
      lt: 9200,
    },
    {
      token: "LINK",
      lt: 9200,
    },
    {
      token: "SNX",
      lt: 9200,
    },
  ],
  adapters: [tier2UniV3Config, tier2VelodromeConfig],
};

const farmUniV3Config: UniV3Config = {
  contract: "UNISWAP_V3_ROUTER",
  allowed: [
    { token0: "WETH", token1: "wstETH", fee: 100 },
    { token0: "WETH", token1: "rETH", fee: 100 },
  ],
};

const farmBalancerConfig: BalancerVaultConfig = {
  contract: "BALANCER_VAULT",
  allowed: [
    {
      pool: "BPT_rETH_ETH",
      status: 2,
    },
    {
      pool: "ECLP_wstETH_WETH",
      status: 2,
    },
    {
      pool: "BPT_WSTETH_ETH",
      status: 2,
    },
  ],
};

const farmVelodromeConfig: VelodromeV2Config = {
  contract: "VELODROME_V2_ROUTER",
  allowed: [
    {
      token0: "wstETH",
      token1: "WETH",
      stable: false,
      factory: VELODROME_V2_DEFAULT_FACTORY,
    },
  ],
};

const farmCreditManager: CreditManagerV3DeployConfig = {
  name: "Farm WETH",
  degenNft: true,
  expirationDate: undefined,
  minDebt: (BigInt(1e4) * POOL_DECIMALS) / POOL_DIVIDER,
  maxDebt: (BigInt(1e5) * POOL_DECIMALS) / POOL_DIVIDER,
  feeInterest: 2500,
  feeLiquidation: 50,
  liquidationPremium: 100,
  feeLiquidationExpired: 50,
  liquidationPremiumExpired: 100,
  poolLimit: (BigInt(3e6) * POOL_DECIMALS) / POOL_DIVIDER,
  collateralTokens: [
    {
      token: "wstETH",
      lt: 9800,
    },
    {
      token: "rETH",
      lt: 9800,
    },

    // Yearn
    { token: "yvWETH", lt: 9600 },
  ],
  adapters: [
    // Swapping
    farmUniV3Config,
    farmBalancerConfig,
    farmVelodromeConfig,
    { contract: "YEARN_WETH_VAULT" },
  ],
};

export const config: PoolV3DeployConfig = {
  id: "optimism-weth-v3",
  symbol: "dWETHV3",
  name: "WETH v3",
  network: "Optimism",
  underlying: "WETH",
  accountAmount: (BigInt(10_000) * POOL_DECIMALS) / POOL_DIVIDER,
  withdrawalFee: 0,
  totalDebtLimit: (BigInt(100_000_000) * POOL_DECIMALS) / POOL_DIVIDER,
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
      limit: (BigInt(6e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    USDC: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: (BigInt(3e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    OP: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: (BigInt(1.8e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    WLD: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 5,
      limit: (BigInt(1e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    LINK: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 5,
      limit: (BigInt(5e4) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    SNX: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 5,
      limit: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    // BOOSTED
    yvOP: {
      minRate: 4,
      maxRate: 1500,
      quotaIncreaseFee: 1,
      limit: (BigInt(5.5e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvUSDC: {
      minRate: 5,
      maxRate: 700,
      quotaIncreaseFee: 0,
      limit: (BigInt(3.3e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },

    // FARMS
    yvWETH: {
      minRate: 4,
      maxRate: 1500,
      quotaIncreaseFee: 1,
      limit: (BigInt(4e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    wstETH: {
      minRate: 4,
      maxRate: 1500,
      quotaIncreaseFee: 1,
      limit: (BigInt(3e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    rETH: {
      minRate: 4,
      maxRate: 1500,
      quotaIncreaseFee: 1,
      limit: (BigInt(3e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
  },
  creditManagers: [tier1CreditManager, tier2CreditManager, farmCreditManager],
  supportsQuotas: true,
};
