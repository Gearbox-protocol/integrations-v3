import {
  BalancerVaultConfig,
  PoolV3DeployConfig,
  UniV2Config,
  UniV3Config,
} from "@gearbox-protocol/sdk-gov";

import { adapters } from "./adapters";

const POOL_DECIMALS = BigInt(1e6);
const POOL_DIVIDER = BigInt(1);

const levUniV2Config: UniV2Config = {
  contract: "UNISWAP_V2_ROUTER",
  allowed: [
    { token0: "WETH", token1: "USDT" },
    { token0: "USDC", token1: "WETH" },
    { token0: "USDC", token1: "USDT" },
    { token0: "DAI", token1: "USDC" },
    { token0: "DAI", token1: "WETH" },
    { token0: "FXS", token1: "FRAX" },
    { token0: "WBTC", token1: "WETH" },
  ],
};

const levUniV3Config: UniV3Config = {
  contract: "UNISWAP_V3_ROUTER",
  allowed: [
    { token0: "SNX", token1: "WETH", fee: 3000 },
    { token0: "WBTC", token1: "WETH", fee: 500 },
    { token0: "DAI", token1: "WETH", fee: 500 },
    { token0: "WBTC", token1: "WETH", fee: 3000 },
    { token0: "DAI", token1: "WETH", fee: 3000 },
    { token0: "USDC", token1: "WETH", fee: 500 },
    { token0: "LDO", token1: "WETH", fee: 3000 },
    { token0: "USDC", token1: "WETH", fee: 10000 },
    { token0: "LDO", token1: "WETH", fee: 10000 },
    { token0: "LQTY", token1: "WETH", fee: 3000 },
    { token0: "FXS", token1: "WETH", fee: 10000 },
    { token0: "USDC", token1: "WETH", fee: 3000 },
    { token0: "DAI", token1: "WETH", fee: 10000 },
    { token0: "WETH", token1: "USDT", fee: 3000 },
    { token0: "FRAX", token1: "USDT", fee: 500 },
    { token0: "WETH", token1: "USDT", fee: 500 },
    { token0: "USDC", token1: "USDT", fee: 500 },
    { token0: "WBTC", token1: "USDT", fee: 3000 },
    { token0: "WETH", token1: "USDT", fee: 10000 },
    { token0: "DAI", token1: "USDT", fee: 100 },
    { token0: "USDC", token1: "USDT", fee: 10000 },
    { token0: "USDC", token1: "USDT", fee: 3000 },
    { token0: "FXS", token1: "USDT", fee: 3000 },
    { token0: "USDC", token1: "USDT", fee: 100 },
    { token0: "LUSD", token1: "USDC", fee: 500 },
    { token0: "FRAX", token1: "USDC", fee: 100 },
    { token0: "LUSD", token1: "USDC", fee: 3000 },
    { token0: "FRAX", token1: "USDC", fee: 500 },
    { token0: "DAI", token1: "USDC", fee: 500 },
    { token0: "WBTC", token1: "USDC", fee: 3000 },
    { token0: "LDO", token1: "USDC", fee: 10000 },
    { token0: "WBTC", token1: "USDC", fee: 10000 },
    { token0: "WBTC", token1: "USDC", fee: 500 },
    { token0: "DAI", token1: "USDC", fee: 100 },
    { token0: "WBTC", token1: "LQTY", fee: 10000 },
    { token0: "sUSD", token1: "FRAX", fee: 500 },
    { token0: "DAI", token1: "FRAX", fee: 500 },
    { token0: "FXS", token1: "FRAX", fee: 10000 },
    { token0: "WBTC", token1: "DAI", fee: 3000 },
    { token0: "FXS", token1: "CVX", fee: 3000 },
    { token0: "CVX", token1: "CRV", fee: 10000 },
    { token0: "WETH", token1: "CRV", fee: 3000 },
    { token0: "WETH", token1: "CRV", fee: 10000 },
    { token0: "WETH", token1: "CVX", fee: 10000 },
    { token0: "SNX", token1: "USDC", fee: 10000 },
    { token0: "OHM", token1: "USDC", fee: 3000 },
    { token0: "WETH", token1: "LINK", fee: 3000 },
  ],
};

const levSushiswapConfig: UniV2Config = {
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
    { token0: "SNX", token1: "WETH" },
  ],
};

const levBalancerConfig: BalancerVaultConfig = {
  contract: "BALANCER_VAULT",
  allowed: [
    {
      pool: "50OHM_50DAI",
      status: 2,
    },
    {
      pool: "B_rETH_STABLE",
      status: 1,
    },
    {
      pool: "USDC_DAI_USDT",
      status: 1,
    },
  ],
};

export const config: PoolV3DeployConfig = {
  id: "mainnet-usdc-lev-v3",
  symbol: "dUSDC-lev-V3",
  name: "USDC v3 farm",
  network: "Mainnet",
  underlying: "USDC",
  accountAmount: BigInt(1_000_000) * POOL_DECIMALS,
  withdrawalFee: 0,
  expectedLiquidityLimit: BigInt(10_000_000) * POOL_DECIMALS,
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
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    STETH: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    wstETH: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    rETH: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    WBTC: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    LINK: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    aDAI: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    cLINK: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    sDAI: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    YieldETH: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    DAI: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    USDT: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    sUSD: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    FRAX: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    GUSD: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    LUSD: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    rETH_f: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    steCRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    cvxsteCRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    stkcvxsteCRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },

    "3Crv": {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    cvx3Crv: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    stkcvx3Crv: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },

    FRAX3CRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    cvxFRAX3CRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    stkcvxFRAX3CRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },

    LUSD3CRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    cvxLUSD3CRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    stkcvxLUSD3CRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },

    crvPlain3andSUSD: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    cvxcrvPlain3andSUSD: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    stkcvxcrvPlain3andSUSD: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },

    gusd3CRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    cvxgusd3CRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    stkcvxgusd3CRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },

    crvFRAX: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    cvxcrvFRAX: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    stkcvxcrvFRAX: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    USDC_DAI_USDT: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    B_rETH_STABLE: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    auraB_rETH_STABLE: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    auraB_rETH_STABLE_vault: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvDAI: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvUSDC: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvWETH: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvWBTC: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvCurve_stETH: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    yvCurve_FRAX: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },

    CVX: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    FXS: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    LQTY: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    CRV: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    LDO: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    SNX: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    BAL: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
    AURA: {
      minRate: 1,
      maxRate: 3000,
      quotaIncreaseFee: 0,
      limit: (BigInt(1e7) * POOL_DECIMALS) / POOL_DIVIDER,
    },
  },
  creditManagers: [
    {
      name: "Farm USDC v3",
      degenNft: false,
      expirationDate: undefined,
      minDebt: (BigInt(1e4) * POOL_DECIMALS) / POOL_DIVIDER,
      maxDebt: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
      poolLimit: (BigInt(10_000_000) * POOL_DECIMALS) / POOL_DIVIDER,
      collateralTokens: [
        { token: "WETH", lt: 85_00 }, // Token address is token from priceFeed map above
        { token: "STETH", lt: 82_50 }, // Token address is token from priceFeed map above
        { token: "wstETH", lt: 82_50 },
        { token: "rETH", lt: 82_50 },
        { token: "WBTC", lt: 85_00 }, // Token address is token from priceFeed map above
        { token: "LINK", lt: 80_00 },

        { token: "aDAI", lt: 92_00 },
        { token: "cLINK", lt: 85_00 },
        { token: "sDAI", lt: 92_00 },

        { token: "DAI", lt: 92_00 }, // Token address is token from priceFeed map above
        { token: "USDT", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "sUSD", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "FRAX", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "GUSD", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "LUSD", lt: 90_00 }, // Token address is token from priceFeed map above

        { token: "rETH_f", lt: 82_50 },

        { token: "steCRV", lt: 82_50 }, // Token address is token from priceFeed map above
        { token: "cvxsteCRV", lt: 82_50 }, // Token address is token from priceFeed map above
        { token: "stkcvxsteCRV", lt: 82_50 },

        { token: "3Crv", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "cvx3Crv", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "stkcvx3Crv", lt: 90_00 },

        { token: "FRAX3CRV", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "cvxFRAX3CRV", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "stkcvxFRAX3CRV", lt: 90_00 },

        { token: "LUSD3CRV", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "cvxLUSD3CRV", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "stkcvxLUSD3CRV", lt: 90_00 },

        { token: "crvPlain3andSUSD", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "cvxcrvPlain3andSUSD", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "stkcvxcrvPlain3andSUSD", lt: 90_00 },

        { token: "gusd3CRV", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "cvxgusd3CRV", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "stkcvxgusd3CRV", lt: 90_00 }, // Token address is token from priceFeed map above

        { token: "crvFRAX", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "cvxcrvFRAX", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "stkcvxcrvFRAX", lt: 90_00 }, // Token address is token from priceFeed map above

        { token: "USDC_DAI_USDT", lt: 82_00 },

        { token: "B_rETH_STABLE", lt: 82_00 },
        { token: "auraB_rETH_STABLE", lt: 82_00 },
        { token: "auraB_rETH_STABLE_vault", lt: 82_00 },

        { token: "yvDAI", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "yvUSDC", lt: 90_00 }, // Token address is token from priceFeed map above
        { token: "yvWETH", lt: 82_50 }, // Token address is token from priceFeed map above
        { token: "yvWBTC", lt: 82_50 }, // Token address is token from priceFeed map above
        { token: "yvCurve_stETH", lt: 82_50 }, // Token address is token from priceFeed map above
        { token: "yvCurve_FRAX", lt: 90_00 }, // Token address is token from priceFeed map above

        { token: "CVX", lt: 0 }, // Token address is token from priceFeed map above
        { token: "FXS", lt: 0 }, // Token address is token from priceFeed map above
        { token: "LQTY", lt: 0 },
        { token: "CRV", lt: 25_00 }, // Token address is token from priceFeed map above
        { token: "LDO", lt: 0 },
        { token: "SNX", lt: 25_00 },
        { token: "BAL", lt: 25_00 },
        { token: "AURA", lt: 0 },
      ],
      adapters: [
        // SWAPPERS
        levUniV3Config,
        levUniV2Config,
        levSushiswapConfig,
        levBalancerConfig,
        // CURVE
        { contract: "CURVE_3CRV_POOL" },
        { contract: "CURVE_FRAX_USDC_POOL" },
        { contract: "CURVE_STETH_GATEWAY" },
        { contract: "CURVE_FRAX_POOL" },
        { contract: "CURVE_SUSD_POOL" },
        { contract: "CURVE_LUSD_POOL" },
        { contract: "CURVE_GUSD_POOL" },
        { contract: "CURVE_SUSD_DEPOSIT" },
        { contract: "CURVE_RETH_ETH_POOL" },

        // YEARN
        { contract: "YEARN_DAI_VAULT" },
        { contract: "YEARN_USDC_VAULT" },
        { contract: "YEARN_WETH_VAULT" },
        { contract: "YEARN_WBTC_VAULT" },
        { contract: "YEARN_CURVE_FRAX_VAULT" },
        { contract: "YEARN_CURVE_STETH_VAULT" },

        // CONVEX
        { contract: "CONVEX_FRAX3CRV_POOL" },
        { contract: "CONVEX_LUSD3CRV_POOL" },
        { contract: "CONVEX_GUSD_POOL" },
        { contract: "CONVEX_SUSD_POOL" },
        { contract: "CONVEX_3CRV_POOL" },
        { contract: "CONVEX_FRAX_USDC_POOL" },
        { contract: "CONVEX_STECRV_POOL" },
        { contract: "CONVEX_BOOSTER" },

        // NEW PROTOCOLS
        { contract: "LIDO_WSTETH" },
        { contract: "AAVE_V2_LENDING_POOL" },
        { contract: "COMPOUND_V2_LINK_POOL" },
        { contract: "MAKER_DSR_VAULT" },
        { contract: "AURA_BOOSTER" },
        { contract: "AURA_B_RETH_STABLE_POOL" },
      ],
    },
  ],
  supportsQuotas: true,
};
