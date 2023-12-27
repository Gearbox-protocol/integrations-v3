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
  feeInterest: 2500,
  feeLiquidation: 150,
  liquidationPremium: 400,
  feeLiquidationExpired: 100,
  liquidationPremiumExpired: 200,
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
    // FARMS
    {
      token: "yvUSDC",
      lt: 9000,
    },
    {
      token: "yvDAI",
      lt: 9000,
    },
    {
      token: "sDAI",
      lt: 9000,
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
    { contract: "YEARN_USDC_VAULT" },
    { contract: "YEARN_DAI_VAULT" },
    { contract: "MAKER_DSR_VAULT" },
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
  feeInterest: 2500,
  feeLiquidation: 150,
  liquidationPremium: 400,
  feeLiquidationExpired: 100,
  liquidationPremiumExpired: 200,
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
  feeInterest: 2500,
  feeLiquidation: 150,
  liquidationPremium: 400,
  feeLiquidationExpired: 100,
  liquidationPremiumExpired: 200,
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

const farmUniV3Config: UniV3Config = {
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
    { token0: "WETH", token1: "CRV", fee: 3000 },
    { token0: "WETH", token1: "CRV", fee: 10000 },
    { token0: "WETH", token1: "CVX", fee: 10000 },
  ],
};

const farmCreditManager: CreditManagerV3DeployConfig = {
  name: "Farm USDC",
  degenNft: true,
  expirationDate: undefined,
  minDebt: (BigInt(2e4) * POOL_DECIMALS) / POOL_DIVIDER,
  maxDebt: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
  feeInterest: 2500,
  feeLiquidation: 150,
  liquidationPremium: 400,
  feeLiquidationExpired: 100,
  liquidationPremiumExpired: 200,
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
      token: "crvUSD",
      lt: 9000,
    },
    {
      token: "MIM",
      lt: 9000,
    },
    // ERC4626
    { token: "sDAI", lt: 9000 },

    // Yearn
    { token: "yvUSDC", lt: 9000 },
    { token: "yvDAI", lt: 9000 },

    // Convex
    { token: "stkcvxcrvUSDUSDC", lt: 8700 },
    { token: "stkcvxcrvUSDUSDT", lt: 8700 },
    { token: "stkcvxcrvUSDFRAX", lt: 8700 },
    { token: "stkcvxMIM_3LP3CRV", lt: 8700 },
    { token: "stkcvxcrvFRAX", lt: 8700 },

    // Rewards
    { token: "CRV", lt: 7250 },
    { token: "CVX", lt: 7250 },

    // Compatibility
    { token: "crvUSDUSDC", lt: 0 },
    { token: "cvxcrvUSDUSDC", lt: 0 },

    { token: "crvUSDUSDT", lt: 0 },
    { token: "cvxcrvUSDUSDT", lt: 0 },

    { token: "crvUSDFRAX", lt: 0 },
    { token: "cvxcrvUSDFRAX", lt: 0 },

    { token: "MIM_3LP3CRV", lt: 0 },
    { token: "cvxMIM_3LP3CRV", lt: 0 },

    { token: "crvFRAX", lt: 0 },
    { token: "cvxcrvFRAX", lt: 0 },

    { token: "3Crv", lt: 0 },
    { token: "crvCVXETH", lt: 0 },
    { token: "crvUSDETHCRV", lt: 0 },
    { token: "SPELL", lt: 0 },
  ],
  adapters: [
    // Swapping
    farmUniV3Config,
    { contract: "CURVE_CVXETH_POOL" },
    { contract: "CURVE_TRI_CRV_POOL" },

    // Curve
    { contract: "CURVE_3CRV_POOL" },
    { contract: "CURVE_FRAX_USDC_POOL" },
    { contract: "CURVE_CRVUSD_USDC_POOL" },
    { contract: "CURVE_CRVUSD_USDT_POOL" },
    { contract: "CURVE_CRVUSD_FRAX_POOL" },
    { contract: "CURVE_MIM_POOL" },

    // Convex
    { contract: "CONVEX_BOOSTER" },
    { contract: "CONVEX_FRAX_USDC_POOL" },
    { contract: "CONVEX_CRVUSD_USDC_POOL" },
    { contract: "CONVEX_CRVUSD_USDT_POOL" },
    { contract: "CONVEX_CRVUSD_FRAX_POOL" },
    { contract: "CONVEX_MIM3CRV_POOL" },

    // Yearn
    { contract: "YEARN_USDC_VAULT" },
    { contract: "YEARN_DAI_VAULT" },

    // ERC4626
    { contract: "MAKER_DSR_VAULT" },
  ],
};

export const config: PoolV3DeployConfig = {
  id: "mainnet-usdc-v3",
  symbol: "dUSDCV3",
  name: "Trade USDC v3",
  network: "Mainnet",
  underlying: "USDC",
  accountAmount: BigInt(100_000) * POOL_DECIMALS,
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
      maxRate: 40,
      quotaIncreaseFee: 0,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    FRAX: {
      minRate: 4,
      maxRate: 40,
      quotaIncreaseFee: 0,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    USDT: {
      minRate: 4,
      maxRate: 40,
      quotaIncreaseFee: 0,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    crvUSD: {
      minRate: 4,
      maxRate: 40,
      quotaIncreaseFee: 0,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    MIM: {
      minRate: 4,
      maxRate: 40,
      quotaIncreaseFee: 0,
      limit: (BigInt(4e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    MKR: {
      minRate: 80,
      maxRate: 2400,
      quotaIncreaseFee: 1,
      limit: (BigInt(3e6) * POOL_DECIMALS) / POOL_DIVIDER,
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
      limit: (BigInt(2.5e6) * POOL_DECIMALS) / POOL_DIVIDER,
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
      limit: (BigInt(2e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    APE: {
      minRate: 240,
      maxRate: 4000,
      quotaIncreaseFee: 1,
      limit: (BigInt(5e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvWETH: {
      minRate: 1,
      maxRate: 1500,
      quotaIncreaseFee: 1,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvWBTC: {
      minRate: 1,
      maxRate: 1500,
      quotaIncreaseFee: 1,
      limit: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },

    // FARMS

    sDAI: {
      minRate: 5,
      maxRate: 500,
      quotaIncreaseFee: 0,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvUSDC: {
      minRate: 50,
      maxRate: 500,
      quotaIncreaseFee: 0,
      limit: (BigInt(4e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvDAI: {
      minRate: 50,
      maxRate: 500,
      quotaIncreaseFee: 0,
      limit: (BigInt(7e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    stkcvxcrvUSDUSDC: {
      minRate: 100,
      maxRate: 520,
      quotaIncreaseFee: 0,
      limit: (BigInt(9.6e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    stkcvxcrvUSDUSDT: {
      minRate: 100,
      maxRate: 700,
      quotaIncreaseFee: 0,
      limit: (BigInt(7.8e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    stkcvxMIM_3LP3CRV: {
      minRate: 100,
      maxRate: 870,
      quotaIncreaseFee: 0,
      limit: (BigInt(6.5e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    stkcvxcrvUSDFRAX: {
      minRate: 100,
      maxRate: 750,
      quotaIncreaseFee: 0,
      limit: (BigInt(4.5e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    stkcvxcrvFRAX: {
      minRate: 100,
      maxRate: 240,
      quotaIncreaseFee: 0,
      limit: (BigInt(20.4e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
  },
  creditManagers: [
    tier1CreditManager,
    tier2CreditManager,
    tier3CreditManager,
    farmCreditManager,
  ],
  supportsQuotas: true,
};
