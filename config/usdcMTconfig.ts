import {
  BalancerVaultConfig,
  PoolV3DeployConfig,
  UniV2Config,
  UniV3Config,
} from "@gearbox-protocol/sdk-gov";

const POOL_DECIMALS = BigInt(1e6);
const POOL_DIVIDER = BigInt(1);

const mtUniV2Config: UniV2Config = {
  contract: "UNISWAP_V2_ROUTER",
  allowed: [
    { token0: "WETH", token1: "USDT" },
    { token0: "USDC", token1: "WETH" },
    { token0: "USDC", token1: "USDT" },
    { token0: "DAI", token1: "USDC" },
    { token0: "DAI", token1: "WETH" },
    { token0: "FXS", token1: "FRAX" },
    { token0: "WBTC", token1: "WETH" },
    { token0: "DAI", token1: "MKR" },
    { token0: "MKR", token1: "WETH" },
    { token0: "LINK", token1: "WETH" },
    { token0: "SNX", token1: "WETH" },
  ],
};

const mtUniV3Config: UniV3Config = {
  contract: "UNISWAP_V3_ROUTER",
  allowed: [
    { token0: "USDC", token1: "WETH", fee: 500 },
    { token0: "WBTC", token1: "WETH", fee: 3000 },
    { token0: "DAI", token1: "USDC", fee: 100 },
    { token0: "FRAX", token1: "USDC", fee: 500 },
    { token0: "WBTC", token1: "WETH", fee: 500 },
    { token0: "USDC", token1: "WETH", fee: 3000 },
    { token0: "WETH", token1: "USDT", fee: 3000 },
    { token0: "DAI", token1: "USDC", fee: 500 },
    { token0: "WBTC", token1: "USDC", fee: 3000 },
    { token0: "WETH", token1: "USDT", fee: 500 },
    { token0: "UNI", token1: "WETH", fee: 3000 },
    { token0: "USDC", token1: "USDT", fee: 100 },
    { token0: "MKR", token1: "WETH", fee: 3000 },
    { token0: "LINK", token1: "WETH", fee: 3000 },
    { token0: "DAI", token1: "FRAX", fee: 500 },
    { token0: "MKR", token1: "WETH", fee: 10000 },
    { token0: "DAI", token1: "WETH", fee: 3000 },
    { token0: "USDC", token1: "USDT", fee: 500 },
    { token0: "DAI", token1: "WETH", fee: 500 },
    { token0: "LDO", token1: "WETH", fee: 3000 },
    { token0: "WBTC", token1: "USDT", fee: 3000 },
    { token0: "WETH", token1: "RPL", fee: 3000 },
    { token0: "USDC", token1: "WETH", fee: 10000 },
    { token0: "APE", token1: "WETH", fee: 3000 },
    { token0: "CRV", token1: "WETH", fee: 3000 },
  ],
};

const mtSushiswapConfig: UniV2Config = {
  contract: "SUSHISWAP_ROUTER",
  allowed: [
    { token0: "WBTC", token1: "WETH" },
    { token0: "WETH", token1: "USDT" },
    { token0: "USDC", token1: "WETH" },
    { token0: "DAI", token1: "WETH" },
    { token0: "WETH", token1: "FXS" },
    { token0: "LDO", token1: "WETH" },
    { token0: "CVX", token1: "WETH" },
    { token0: "CRV", token1: "WETH" },
    { token0: "LINK", token1: "WETH" },
  ],
};

const mtFraxswapConfig: UniV2Config = {
  contract: "FRAXSWAP_ROUTER",
  allowed: [
    { token0: "FRAX", token1: "FXS" },
    { token0: "FRAX", token1: "WETH" },
  ],
};

export const config: PoolV3DeployConfig = {
  id: "mainnet-usdc-mt-v3",
  symbol: "dUSDCV3",
  name: "Trade USDC v3",
  network: "Mainnet",
  underlying: "USDC",
  accountAmount: BigInt(1_000_000) * POOL_DECIMALS,
  withdrawalFee: 0,
  expectedLiquidityLimit: BigInt(35_000_000) * POOL_DECIMALS,
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
    WETH: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvWETH: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 1,
      limit: (BigInt(10e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    DAI: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    USDT: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(30e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    WBTC: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(10e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    FRAX: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(10e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    MKR: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 2,
      limit: (BigInt(2e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    UNI: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 2,
      limit: (BigInt(2e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    LINK: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 2,
      limit: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    LDO: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 2,
      limit: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    CRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 2,
      limit: (BigInt(2e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    APE: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 2,
      limit: (BigInt(3e5) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    CVX: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 2,
      limit: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    FXS: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 2,
      limit: (BigInt(2e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
  },
  creditManagers: [
    {
      name: "Trade USDC -> Crypto v3",
      degenNft: false,
      expirationDate: undefined,
      minDebt: (BigInt(1e4) * POOL_DECIMALS) / POOL_DIVIDER,
      maxDebt: (BigInt(1e5) * POOL_DECIMALS) / POOL_DIVIDER,
      poolLimit: (BigInt(5_000_000) * POOL_DECIMALS) / POOL_DIVIDER,
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
          token: "USDT",
          lt: 9000,
        },
        {
          token: "DAI",
          lt: 9000,
        },
        {
          token: "FRAX",
          lt: 9000,
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

        // COMPATIBILITY
        { token: "3Crv", lt: 0 },
        { token: "crvFRAX", lt: 0 },
        { token: "crvCVXETH", lt: 0 },
        { token: "crvUSDTWBTCWETH", lt: 0 },
        { token: "LDOETH", lt: 0 },
        { token: "crvUSDETHCRV", lt: 0 },
        { token: "crvUSD", lt: 0 },
      ],
      adapters: [
        mtUniV2Config,
        mtUniV3Config,
        mtSushiswapConfig,
        mtFraxswapConfig,
        { contract: "CURVE_3CRV_POOL" },
        { contract: "CURVE_FRAX_USDC_POOL" },
        { contract: "CURVE_CVXETH_POOL" },
        { contract: "CURVE_3CRYPTO_POOL" },
        { contract: "CURVE_LDOETH_POOL" },
        { contract: "CURVE_TRI_CRV_POOL" },
      ],
    },
    {
      name: "Trade USDC -> WETH SmartLong v3",
      degenNft: false,
      expirationDate: undefined,
      minDebt: (BigInt(1e4) * POOL_DECIMALS) / POOL_DIVIDER,
      maxDebt: (BigInt(2e6) * POOL_DECIMALS) / POOL_DIVIDER,
      poolLimit: (BigInt(30_000_000) * POOL_DECIMALS) / POOL_DIVIDER,
      collateralTokens: [
        {
          token: "WETH",
          lt: 8700,
        },
        {
          token: "yvWETH",
          lt: 8500,
        },
      ],
      adapters: [
        {
          contract: "UNISWAP_V3_ROUTER",
          allowed: [{ token0: "USDC", token1: "WETH", fee: 500 }],
        },
        {
          contract: "YEARN_WETH_VAULT",
        },
      ],
    },
  ],
  supportsQuotas: true,
};
