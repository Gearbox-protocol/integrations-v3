import {
  BalancerVaultConfig,
  CreditManagerV3DeployConfig,
  PoolV3DeployConfig,
  UniV2Config,
  UniV3Config,
  VelodromeV2Config,
} from "@gearbox-protocol/sdk-gov";

const POOL_DECIMALS = BigInt(1e6);
const POOL_DIVIDER = BigInt(1);

const VELODROME_V2_DEFAULT_FACTORY =
  "0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a";

const tier1UniV3Config: UniV3Config = {
  contract: "UNISWAP_V3_ROUTER",
  allowed: [
    { token0: "WETH", token1: "OP", fee: 3000 },
    { token0: "WETH", token1: "USDC", fee: 500 },
    { token0: "WETH", token1: "USDC", fee: 3000 },
    { token0: "WETH", token1: "WBTC", fee: 3000 },
    { token0: "wstETH", token1: "WETH", fee: 100 },
    { token0: "WETH", token1: "WBTC", fee: 500 },
    { token0: "OP", token1: "USDC", fee: 3000 },
    { token0: "WETH", token1: "OP", fee: 500 },
    { token0: "WETH", token1: "rETH", fee: 500 },
  ],
};

const tier1BalancerConfig: BalancerVaultConfig = {
  contract: "BALANCER_VAULT",
  allowed: [
    {
      pool: "BPT_rETH_ETH",
      status: 2,
    },
    {
      pool: "BPT_WSTETH_ETH",
      status: 2,
    },
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
      token0: "OP",
      token1: "USDC",
      stable: false,
      factory: VELODROME_V2_DEFAULT_FACTORY,
    },
  ],
};

const tier1CreditManager: CreditManagerV3DeployConfig = {
  name: "Trade USDC Tier 1 Optimism",
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
      token: "WETH",
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
      token: "yvWETH",
      lt: 9400,
    },
    {
      token: "wstETH",
      lt: 9400,
    },
    {
      token: "rETH",
      lt: 9400,
    },
    {
      token: "yvOP",
      lt: 9400,
    },
    // COMPATIBILITY
    // { token: "wstETHCRV", lt: 0 },
  ],
  adapters: [
    tier1UniV3Config,
    tier1BalancerConfig,
    tier1VelodromeConfig,
    // { contract: "CURVE_ETH_WSTETH_GATEWAY" }, THIS NEEDS TO BE DEPLOYED !!
    { contract: "YEARN_WETH_VAULT" },
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

const tier2CreditManager: CreditManagerV3DeployConfig = {
  name: "Trade USDC Tier 2 Optimism",
  degenNft: false,
  expirationDate: undefined,
  minDebt: (BigInt(1e3) * POOL_DECIMALS) / POOL_DIVIDER,
  maxDebt: (BigInt(5e4) * POOL_DECIMALS) / POOL_DIVIDER,
  feeInterest: 2500,
  feeLiquidation: 100,
  liquidationPremium: 200,
  feeLiquidationExpired: 100,
  liquidationPremiumExpired: 200,
  poolLimit: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
  collateralTokens: [
    {
      token: "WETH",
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
  adapters: [tier2UniV3Config],
};

const farmUniV3Config: UniV3Config = {
  contract: "UNISWAP_V3_ROUTER",
  allowed: [
    { token0: "USDC", token1: "USDT", fee: 100 },
    { token0: "DAI", token1: "USDC", fee: 100 },
    { token0: "USDT", token1: "DAI", fee: 100 },
  ],
};

const farmCreditManager: CreditManagerV3DeployConfig = {
  name: "Farm USDC",
  degenNft: true,
  expirationDate: undefined,
  minDebt: (BigInt(1e4) * POOL_DECIMALS) / POOL_DIVIDER,
  maxDebt: (BigInt(3e5) * POOL_DECIMALS) / POOL_DIVIDER,
  feeInterest: 2500,
  feeLiquidation: 50,
  liquidationPremium: 100,
  feeLiquidationExpired: 50,
  liquidationPremiumExpired: 100,
  poolLimit: (BigInt(3e6) * POOL_DECIMALS) / POOL_DIVIDER,
  collateralTokens: [
    {
      token: "DAI",
      lt: 9800,
    },
    {
      token: "USDT",
      lt: 9800,
    },

    // Yearn
    { token: "yvUSDC", lt: 9600 },
    { token: "yvDAI", lt: 9600 },
    { token: "yvUSDT", lt: 9600 },

    // Compatibility
    { token: "3Crv", lt: 0 },
  ],
  adapters: [
    // Swapping
    farmUniV3Config,
    { contract: "CURVE_3CRV_POOL" },
    { contract: "YEARN_DAI_VAULT" },
    { contract: "YEARN_USDC_VAULT" },
    { contract: "YEARN_USDT_VAULT" },
  ],
};

export const config: PoolV3DeployConfig = {
  id: "optimism-usdc-v3",
  symbol: "dUSDCV3",
  name: "Trade USDC v3",
  network: "Optimism",
  underlying: "USDC",
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
      limit: (BigInt(3e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    WETH: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: (BigInt(3e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    OP: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: (BigInt(3e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    WLD: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 5,
      limit: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    LINK: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 5,
      limit: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    SNX: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 5,
      limit: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },

    // BOOSTED
    yvWETH: {
      minRate: 4,
      maxRate: 1500,
      quotaIncreaseFee: 1,
      limit: (BigInt(4e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvOP: {
      minRate: 4,
      maxRate: 1500,
      quotaIncreaseFee: 1,
      limit: (BigInt(7e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    wstETH: {
      minRate: 4,
      maxRate: 1500,
      quotaIncreaseFee: 1,
      limit: (BigInt(7e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    rETH: {
      minRate: 4,
      maxRate: 1500,
      quotaIncreaseFee: 1,
      limit: (BigInt(1.5e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },

    // FARMS
    yvDAI: {
      minRate: 5,
      maxRate: 850,
      quotaIncreaseFee: 0,
      limit: (BigInt(4e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvUSDC: {
      minRate: 5,
      maxRate: 700,
      quotaIncreaseFee: 0,
      limit: (BigInt(3e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvUSDT: {
      minRate: 5,
      maxRate: 900,
      quotaIncreaseFee: 0,
      limit: (BigInt(3e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
  },
  creditManagers: [tier1CreditManager, tier2CreditManager, farmCreditManager],
  supportsQuotas: true,
};
