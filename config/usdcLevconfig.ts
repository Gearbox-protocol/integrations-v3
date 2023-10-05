import {
  PoolV3CoreConfigurator,
  PoolV3DeployConfig,
} from "@gearbox-protocol/sdk-gov";

import { adapters } from "./adapters";

const POOL_DECIMALS = BigInt(1e6);
const POOL_DIVIDER = BigInt(1);

export const config: PoolV3DeployConfig = {
  id: "mainnet-usdc-lev-v3",
  symbol: "dUSDC-lev-V3",
  name: "Diesel USDC V3 leverage pool",
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
  },
  creditManagers: [
    {
      degenNft: false,
      expirationDate: undefined,
      minDebt: (BigInt(1e4) * POOL_DECIMALS) / POOL_DIVIDER,
      maxDebt: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
      poolLimit: (BigInt(10_000_000) * POOL_DECIMALS) / POOL_DIVIDER,
      collateralTokens: [
        { token: "WETH", lt: 85_00 }, // Token address is token from priceFeed map above
        { token: "STETH", lt: 82_50 }, // Token address is token from priceFeed map above
        { token: "wstETH", lt: 82_50 },
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
        { token: "SNX", lt: 25 },
      ],
      adapters: [
        ...adapters,
        { contract: "LIDO_WSTETH" },
        { contract: "AAVE_V2_LENDING_POOL" },
        { contract: "COMPOUND_V2_LINK_POOL" },
        { contract: "MAKER_DSR_VAULT" },
      ],
    },
  ],
  supportsQuotas: true,
};

const poolCfg = PoolV3CoreConfigurator.new(config);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
