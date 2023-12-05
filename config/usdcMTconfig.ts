import {
  CreditManagerV3DeployConfig,
  PoolV3DeployConfig,
  UniV2Config,
  UniV3Config,
} from "@gearbox-protocol/sdk-gov";

const POOL_DECIMALS = BigInt(1e6);
const POOL_DIVIDER = BigInt(1);

const tier1UniV2Config: UniV2Config = {
  contract: "UNISWAP_V2_ROUTER",
  allowed: [
    { token0: "WETH", token1: "USDT" },
    { token0: "USDC", token1: "WETH" },
    { token0: "USDC", token1: "USDT" },
    { token0: "DAI", token1: "USDC" },
    { token0: "DAI", token1: "WETH" },
    { token0: "WBTC", token1: "WETH" },
  ],
};

const tier1UniV3Config: UniV3Config = {
  contract: "UNISWAP_V3_ROUTER",
  allowed: [
    { token0: "USDC", token1: "WETH", fee: 500 },
    { token0: "WBTC", token1: "WETH", fee: 3000 },
    { token0: "DAI", token1: "USDC", fee: 100 },
    { token0: "WBTC", token1: "WETH", fee: 500 },
    { token0: "USDC", token1: "WETH", fee: 3000 },
    { token0: "WETH", token1: "USDT", fee: 3000 },
    { token0: "DAI", token1: "USDC", fee: 500 },
    { token0: "WBTC", token1: "USDC", fee: 3000 },
    { token0: "WETH", token1: "USDT", fee: 500 },
    { token0: "USDC", token1: "USDT", fee: 100 },
    { token0: "DAI", token1: "WETH", fee: 3000 },
    { token0: "USDC", token1: "USDT", fee: 500 },
    { token0: "DAI", token1: "WETH", fee: 500 },
    { token0: "WBTC", token1: "USDT", fee: 3000 },
    { token0: "USDC", token1: "WETH", fee: 10000 },
  ],
};

const tier1SushiswapConfig: UniV2Config = {
  contract: "SUSHISWAP_ROUTER",
  allowed: [
    { token0: "WBTC", token1: "WETH" },
    { token0: "WETH", token1: "USDT" },
    { token0: "USDC", token1: "WETH" },
    { token0: "DAI", token1: "WETH" },
  ],
};

const tier1CreditManager: CreditManagerV3DeployConfig = {
  name: "Trade USDC Tier 1",
  degenNft: false,
  expirationDate: undefined,
  minDebt: (BigInt(2e4) * POOL_DECIMALS) / POOL_DIVIDER,
  maxDebt: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
  poolLimit: (BigInt(3e6) * POOL_DECIMALS) / POOL_DIVIDER,
  collateralTokens: [
    {
      token: "WETH",
      lt: 9000,
    },
    {
      token: "WBTC",
      lt: 9000,
    },
    {
      token: "STETH",
      lt: 9000,
    },
    {
      token: "DAI",
      lt: 9000,
    },
    {
      token: "USDT",
      lt: 9000,
    },
    {
      token: "yvWETH",
      lt: 8700,
    },
    {
      token: "yvWBTC",
      lt: 8700,
    },
    // COMPATIBILITY
    { token: "3Crv", lt: 0 },
    { token: "crvUSDTWBTCWETH", lt: 0 },
    { token: "steCRV", lt: 0 },
  ],
  adapters: [
    tier1UniV2Config,
    tier1UniV3Config,
    tier1SushiswapConfig,
    { contract: "CURVE_3CRV_POOL" },
    { contract: "CURVE_3CRYPTO_POOL" },
    { contract: "CURVE_STETH_GATEWAY" },
    { contract: "YEARN_WETH_VAULT" },
    { contract: "YEARN_WBTC_VAULT" },
  ],
};

const tier2UniV2Config: UniV2Config = {
  contract: "UNISWAP_V2_ROUTER",
  allowed: [
    { token0: "WETH", token1: "USDT" },
    { token0: "USDC", token1: "WETH" },
    { token0: "USDC", token1: "USDT" },
    { token0: "DAI", token1: "USDC" },
    { token0: "DAI", token1: "WETH" },
    { token0: "DAI", token1: "MKR" },
    { token0: "MKR", token1: "WETH" },
    { token0: "LINK", token1: "WETH" },
  ],
};

const tier2UniV3Config: UniV3Config = {
  contract: "UNISWAP_V3_ROUTER",
  allowed: [
    { token0: "USDC", token1: "WETH", fee: 500 },
    { token0: "DAI", token1: "USDC", fee: 100 },
    { token0: "USDC", token1: "WETH", fee: 3000 },
    { token0: "WETH", token1: "USDT", fee: 3000 },
    { token0: "DAI", token1: "USDC", fee: 500 },
    { token0: "WETH", token1: "USDT", fee: 500 },
    { token0: "UNI", token1: "WETH", fee: 3000 },
    { token0: "USDC", token1: "USDT", fee: 100 },
    { token0: "MKR", token1: "WETH", fee: 3000 },
    { token0: "LINK", token1: "WETH", fee: 3000 },
    { token0: "MKR", token1: "WETH", fee: 10000 },
    { token0: "DAI", token1: "WETH", fee: 3000 },
    { token0: "USDC", token1: "USDT", fee: 500 },
    { token0: "DAI", token1: "WETH", fee: 500 },
    { token0: "LDO", token1: "WETH", fee: 3000 },
    { token0: "USDC", token1: "WETH", fee: 10000 },
  ],
};

const tier2SushiswapConfig: UniV2Config = {
  contract: "SUSHISWAP_ROUTER",
  allowed: [
    { token0: "WETH", token1: "USDT" },
    { token0: "USDC", token1: "WETH" },
    { token0: "DAI", token1: "WETH" },
    { token0: "LDO", token1: "WETH" },
    { token0: "LINK", token1: "WETH" },
  ],
};

const tier2CreditManager: CreditManagerV3DeployConfig = {
  name: "Trade USDC Tier 2",
  degenNft: false,
  expirationDate: undefined,
  minDebt: (BigInt(2e4) * POOL_DECIMALS) / POOL_DIVIDER,
  maxDebt: (BigInt(5e5) * POOL_DECIMALS) / POOL_DIVIDER,
  poolLimit: (BigInt(3e6) * POOL_DECIMALS) / POOL_DIVIDER,
  collateralTokens: [
    {
      token: "WETH",
      lt: 9000,
    },
    {
      token: "DAI",
      lt: 9000,
    },
    {
      token: "USDT",
      lt: 9000,
    },
    {
      token: "MKR",
      lt: 8250,
    },
    {
      token: "UNI",
      lt: 8250,
    },
    {
      token: "LINK",
      lt: 8250,
    },
    {
      token: "LDO",
      lt: 8250,
    },
  ],
  adapters: [tier2UniV2Config, tier2UniV3Config, tier2SushiswapConfig],
};

const tier3UniV2Config: UniV2Config = {
  contract: "UNISWAP_V2_ROUTER",
  allowed: [
    { token0: "WETH", token1: "USDT" },
    { token0: "USDC", token1: "WETH" },
    { token0: "USDC", token1: "USDT" },
    { token0: "DAI", token1: "USDC" },
    { token0: "DAI", token1: "WETH" },
    { token0: "FXS", token1: "FRAX" },
    { token0: "SNX", token1: "WETH" },
  ],
};

const tier3UniV3Config: UniV3Config = {
  contract: "UNISWAP_V3_ROUTER",
  allowed: [
    { token0: "USDC", token1: "WETH", fee: 500 },
    { token0: "DAI", token1: "USDC", fee: 100 },
    { token0: "FRAX", token1: "USDC", fee: 500 },
    { token0: "USDC", token1: "WETH", fee: 3000 },
    { token0: "WETH", token1: "USDT", fee: 3000 },
    { token0: "DAI", token1: "USDC", fee: 500 },
    { token0: "WETH", token1: "USDT", fee: 500 },
    { token0: "USDC", token1: "USDT", fee: 100 },
    { token0: "DAI", token1: "FRAX", fee: 500 },
    { token0: "DAI", token1: "WETH", fee: 3000 },
    { token0: "USDC", token1: "USDT", fee: 500 },
    { token0: "DAI", token1: "WETH", fee: 500 },
    { token0: "USDC", token1: "WETH", fee: 10000 },
    { token0: "APE", token1: "WETH", fee: 3000 },
    { token0: "WETH", token1: "CRV", fee: 3000 },
    { token0: "WETH", token1: "CRV", fee: 10000 },
    { token0: "WETH", token1: "CVX", fee: 10000 },
    { token0: "FXS", token1: "FRAX", fee: 10000 },
    { token0: "FXS", token1: "FRAX", fee: 10000 },
  ],
};

const tier3SushiswapConfig: UniV2Config = {
  contract: "SUSHISWAP_ROUTER",
  allowed: [
    { token0: "WETH", token1: "USDT" },
    { token0: "USDC", token1: "WETH" },
    { token0: "DAI", token1: "WETH" },
    { token0: "WETH", token1: "FXS" },
    { token0: "CVX", token1: "WETH" },
    { token0: "CRV", token1: "WETH" },
  ],
};

const tier3FraxswapConfig: UniV2Config = {
  contract: "FRAXSWAP_ROUTER",
  allowed: [
    { token0: "FRAX", token1: "FXS" },
    { token0: "FRAX", token1: "WETH" },
  ],
};

const tier3CreditManager: CreditManagerV3DeployConfig = {
  name: "Trade USDC Tier 3",
  degenNft: false,
  expirationDate: undefined,
  minDebt: (BigInt(2e4) * POOL_DECIMALS) / POOL_DIVIDER,
  maxDebt: (BigInt(2e5) * POOL_DECIMALS) / POOL_DIVIDER,
  poolLimit: (BigInt(3e6) * POOL_DECIMALS) / POOL_DIVIDER,
  collateralTokens: [
    {
      token: "WETH",
      lt: 9000,
    },
    {
      token: "DAI",
      lt: 9000,
    },
    {
      token: "USDT",
      lt: 9000,
    },
    {
      token: "FRAX",
      lt: 9000,
    },
    {
      token: "CRV",
      lt: 7250,
    },
    {
      token: "CVX",
      lt: 7250,
    },
    {
      token: "FXS",
      lt: 7250,
    },
    {
      token: "APE",
      lt: 7250,
    },
    // COMPATIBILITY
    { token: "crvCVXETH", lt: 0 },
    { token: "crvUSDETHCRV", lt: 0 },
    { token: "crvUSD", lt: 0 },
  ],
  adapters: [
    tier3UniV2Config,
    tier3UniV3Config,
    tier3SushiswapConfig,
    tier3FraxswapConfig,
    { contract: "CURVE_CVXETH_POOL" },
    { contract: "CURVE_TRI_CRV_POOL" },
  ],
};

export const config: PoolV3DeployConfig = {
  id: "mainnet-usdc-mt-v3",
  symbol: "dUSDCV3",
  name: "Trade USDC v3",
  network: "Mainnet",
  underlying: "USDC",
  accountAmount: BigInt(100_000) * POOL_DECIMALS,
  withdrawalFee: 0,
  expectedLiquidityLimit: BigInt(100_000_000) * POOL_DECIMALS,
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
    WBTC: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    WETH: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    STETH: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    DAI: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    FRAX: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    USDT: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    MKR: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 1,
      limit: (BigInt(5e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    UNI: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 1,
      limit: (BigInt(5e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    LINK: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 1,
      limit: (BigInt(5e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    LDO: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 1,
      limit: (BigInt(5e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    CRV: {
      minRate: 240,
      maxRate: 4000,
      quotaIncreaseFee: 1,
      limit: (BigInt(2.5e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    CVX: {
      minRate: 240,
      maxRate: 4000,
      quotaIncreaseFee: 1,
      limit: (BigInt(2.5e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    FXS: {
      minRate: 240,
      maxRate: 4000,
      quotaIncreaseFee: 1,
      limit: (BigInt(2.5e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    APE: {
      minRate: 240,
      maxRate: 4000,
      quotaIncreaseFee: 1,
      limit: (BigInt(2.5e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvWETH: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: (BigInt(10e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvWBTC: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: (BigInt(10e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
  },
  creditManagers: [tier1CreditManager, tier2CreditManager, tier3CreditManager],
  supportsQuotas: true,
};
