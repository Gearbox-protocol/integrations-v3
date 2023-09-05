/*
 * Copyright (c) 2022. Gearbox
 */
import { UNISWAP_V3_QUOTER, WAD } from "@gearbox-protocol/sdk";
import { BigNumber } from "ethers";

import {
  CMConfig,
  UniswapV2PairConfig,
  UniswapV3PoolConfig,
} from "../core/pool";
import { adapters } from "./adapters";

const standardUniV2Config: Array<UniswapV2PairConfig> = [
  { token0: "WETH", token1: "USDT" },
  { token0: "USDC", token1: "WETH" },
  { token0: "USDC", token1: "USDT" },
  { token0: "DAI", token1: "USDC" },
  { token0: "DAI", token1: "WETH" },
  { token0: "FXS", token1: "FRAX" },
  { token0: "WBTC", token1: "WETH" },
];

const standardUniV3Config: Array<UniswapV3PoolConfig> = [
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
];

const standardSushiswapConfig: Array<UniswapV2PairConfig> = [
  { token0: "WBTC", token1: "WETH" },
  { token0: "WETH", token1: "USDT" },
  { token0: "USDC", token1: "WETH" },
  { token0: "DAI", token1: "WETH" },
  { token0: "WETH", token1: "FXS" },
  { token0: "LDO", token1: "WETH" },
  { token0: "CVX", token1: "WETH" },
  { token0: "CRV", token1: "WETH" },
  { token0: "SNX", token1: "WETH" },
];

export const mainnetCreditManagers: Array<CMConfig> = [
  {
    symbol: "DAI",
    minAmount: BigInt(150_000) * WAD,
    maxAmount: BigInt(1_000_000) * WAD, // maxBorrowAmount = 10K + 3 x 10K = 40K
    collateralTokens: [
      // Liquidation threshold will be multiplied x100 to be used as CreditFilter.sol contract parameter

      { symbol: "WETH", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "STETH", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "WBTC", liquidationThreshold: 85 }, // Token address is token from priceFeed map above

      { symbol: "USDC", liquidationThreshold: 92 }, // Token address is token from priceFeed map above
      { symbol: "USDT", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "sUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "FRAX", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "GUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "LUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above

      { symbol: "steCRV", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "cvxsteCRV", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxsteCRV", liquidationThreshold: 82.5 },

      { symbol: "3Crv", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvx3Crv", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvx3Crv", liquidationThreshold: 90 },

      { symbol: "FRAX3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxFRAX3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxFRAX3CRV", liquidationThreshold: 90 },

      { symbol: "LUSD3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxLUSD3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxLUSD3CRV", liquidationThreshold: 90 },

      { symbol: "crvPlain3andSUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvPlain3andSUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvPlain3andSUSD", liquidationThreshold: 90 },

      { symbol: "gusd3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxgusd3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxgusd3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above

      { symbol: "crvFRAX", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvFRAX", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvFRAX", liquidationThreshold: 90 }, // Token address is token from priceFeed map above

      { symbol: "yvDAI", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "yvUSDC", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "yvWETH", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "yvWBTC", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "yvCurve_stETH", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "yvCurve_FRAX", liquidationThreshold: 90 }, // Token address is token from priceFeed map above

      { symbol: "CVX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "FXS", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "LQTY", liquidationThreshold: 0 },
      { symbol: "CRV", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "LDO", liquidationThreshold: 0 },
      { symbol: "SNX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
    ],
    uniV2Pairs: standardUniV2Config,
    uniV3Pools: standardUniV3Config,
    sushiswapPairs: standardSushiswapConfig,
    adapters,
  },
  {
    symbol: "USDC",
    minAmount: BigInt(150_000) * BigInt(1_000_000),
    maxAmount: BigInt(1_000_000) * BigInt(1_000_000),
    collateralTokens: [
      // Liquidation threshold will be multiplied x100 to be used as CreditFilter.sol contract parameter
      { symbol: "WETH", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "STETH", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "WBTC", liquidationThreshold: 85 }, // Token address is token from priceFeed map above

      { symbol: "DAI", liquidationThreshold: 92 }, // Token address is token from priceFeed map above
      { symbol: "USDT", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "sUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "FRAX", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "GUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "LUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above

      { symbol: "steCRV", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "cvxsteCRV", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxsteCRV", liquidationThreshold: 82.5 },

      { symbol: "3Crv", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvx3Crv", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvx3Crv", liquidationThreshold: 90 },

      { symbol: "FRAX3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxFRAX3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxFRAX3CRV", liquidationThreshold: 90 },

      { symbol: "LUSD3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxLUSD3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxLUSD3CRV", liquidationThreshold: 90 },

      { symbol: "crvPlain3andSUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvPlain3andSUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvPlain3andSUSD", liquidationThreshold: 90 },

      { symbol: "gusd3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxgusd3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxgusd3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above

      { symbol: "crvFRAX", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvFRAX", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvFRAX", liquidationThreshold: 90 }, // Token address is token from priceFeed map above

      { symbol: "yvDAI", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "yvUSDC", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "yvWETH", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "yvWBTC", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "yvCurve_stETH", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "yvCurve_FRAX", liquidationThreshold: 90 }, // Token address is token from priceFeed map above

      { symbol: "CVX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "FXS", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "LQTY", liquidationThreshold: 0 },
      { symbol: "CRV", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "LDO", liquidationThreshold: 0 },
      { symbol: "SNX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
    ],
    uniV2Pairs: standardUniV2Config,
    uniV3Pools: standardUniV3Config,
    sushiswapPairs: standardSushiswapConfig,
    adapters,
  },

  {
    symbol: "WETH",

    minAmount: BigInt(100) * WAD, // 0.3 WETH
    maxAmount: BigInt(600) * WAD, // 100WETH ~ 400K
    collateralTokens: [
      // Liquidation threshold will be multiplied x100 to be used as CreditFilter.sol contract parameter
      { symbol: "STETH", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "WBTC", liquidationThreshold: 85 }, // Token address is token from priceFeed map above

      { symbol: "USDC", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "DAI", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "USDT", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "sUSD", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "FRAX", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "GUSD", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "LUSD", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above

      { symbol: "steCRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxsteCRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxsteCRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above

      { symbol: "3Crv", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvx3Crv", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvx3Crv", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "FRAX3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxFRAX3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxFRAX3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "LUSD3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxLUSD3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxLUSD3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "crvPlain3andSUSD", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvPlain3andSUSD", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvPlain3andSUSD", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "gusd3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxgusd3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxgusd3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "crvFRAX", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvFRAX", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvFRAX", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "yvDAI", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "yvUSDC", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "yvWETH", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "yvWBTC", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "yvCurve_stETH", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "yvCurve_FRAX", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "CVX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "FXS", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "LQTY", liquidationThreshold: 0 },
      { symbol: "CRV", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "LDO", liquidationThreshold: 0 },
      { symbol: "SNX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
    ],
    uniV2Pairs: standardUniV2Config,
    uniV3Pools: standardUniV3Config,
    sushiswapPairs: standardSushiswapConfig,
    adapters,
  },

  {
    symbol: "wstETH",

    minAmount: BigInt(100) * WAD, // 0.3 WETH
    maxAmount: BigInt(600) * WAD, // 100WETH ~ 400K
    collateralTokens: [
      // Liquidation threshold will be multiplied x100 to be used as CreditFilter.sol contract parameter
      { symbol: "STETH", liquidationThreshold: 94.5 }, // Token address is token from priceFeed map above
      { symbol: "WETH", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "WBTC", liquidationThreshold: 85 }, // Token address is token from priceFeed map above

      { symbol: "USDC", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "DAI", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "USDT", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "sUSD", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "FRAX", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "GUSD", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "LUSD", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above

      { symbol: "steCRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxsteCRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxsteCRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above

      { symbol: "3Crv", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvx3Crv", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvx3Crv", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "FRAX3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxFRAX3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxFRAX3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "LUSD3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxLUSD3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxLUSD3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "crvPlain3andSUSD", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvPlain3andSUSD", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvPlain3andSUSD", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "gusd3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxgusd3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxgusd3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "crvFRAX", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvFRAX", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvFRAX", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "yvDAI", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "yvUSDC", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "yvWETH", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "yvWBTC", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "yvCurve_stETH", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "yvCurve_FRAX", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "CVX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "FXS", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "LQTY", liquidationThreshold: 0 },
      { symbol: "CRV", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "LDO", liquidationThreshold: 0 },
      { symbol: "SNX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
    ],
    uniV2Pairs: standardUniV2Config,
    uniV3Pools: standardUniV3Config,
    sushiswapPairs: standardSushiswapConfig,
    adapters: [...adapters, "LIDO_WSTETH"],
  },

  {
    symbol: "WBTC",

    minAmount: BigNumber.from(10).pow(8).mul(75).div(10),
    maxAmount: BigNumber.from(10).pow(8).mul(50),
    collateralTokens: [
      // Liquidation threshold will be multiplied x100 to be used as CreditFilter.sol contract parameter
      { symbol: "WETH", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "STETH", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above

      { symbol: "USDC", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "DAI", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "USDT", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "sUSD", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "FRAX", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "GUSD", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "LUSD", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above

      { symbol: "steCRV", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "cvxsteCRV", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxsteCRV", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above

      { symbol: "3Crv", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvx3Crv", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvx3Crv", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "FRAX3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxFRAX3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxFRAX3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "LUSD3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxLUSD3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxLUSD3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "crvPlain3andSUSD", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvPlain3andSUSD", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvPlain3andSUSD", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "gusd3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxgusd3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxgusd3CRV", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "crvFRAX", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvFRAX", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvFRAX", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "yvDAI", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "yvUSDC", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "yvWETH", liquidationThreshold: 80 }, // Token address is token from priceFeed map above
      { symbol: "yvWBTC", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "yvCurve_stETH", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "yvCurve_FRAX", liquidationThreshold: 80 }, // Token address is token from priceFeed map above

      { symbol: "CVX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "FXS", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "LQTY", liquidationThreshold: 0 },
      { symbol: "CRV", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "LDO", liquidationThreshold: 0 },
      { symbol: "SNX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
    ],
    uniV2Pairs: standardUniV2Config,
    uniV3Pools: standardUniV3Config,
    sushiswapPairs: standardSushiswapConfig,
    adapters,
  },
  {
    symbol: "FRAX",
    minAmount: BigInt(150_000) * WAD,
    maxAmount: BigInt(1_000_000) * WAD, // maxBorrowAmount = 10K + 3 x 10K = 40K
    collateralTokens: [
      // Liquidation threshold will be multiplied x100 to be used as CreditFilter.sol contract parameter

      { symbol: "WETH", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "STETH", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "WBTC", liquidationThreshold: 85 }, // Token address is token from priceFeed map above

      { symbol: "USDC", liquidationThreshold: 92 }, // Token address is token from priceFeed map above
      { symbol: "USDT", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "sUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "DAI", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "GUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "LUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above

      { symbol: "steCRV", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "cvxsteCRV", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxsteCRV", liquidationThreshold: 82.5 },

      { symbol: "3Crv", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvx3Crv", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvx3Crv", liquidationThreshold: 90 },

      { symbol: "FRAX3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxFRAX3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxFRAX3CRV", liquidationThreshold: 90 },

      { symbol: "LUSD3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxLUSD3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxLUSD3CRV", liquidationThreshold: 90 },

      { symbol: "crvPlain3andSUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvPlain3andSUSD", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvPlain3andSUSD", liquidationThreshold: 90 },

      { symbol: "gusd3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxgusd3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxgusd3CRV", liquidationThreshold: 90 }, // Token address is token from priceFeed map above

      { symbol: "crvFRAX", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvFRAX", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvFRAX", liquidationThreshold: 90 }, // Token address is token from priceFeed map above

      { symbol: "yvDAI", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "yvUSDC", liquidationThreshold: 90 }, // Token address is token from priceFeed map above
      { symbol: "yvWETH", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "yvWBTC", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "yvCurve_stETH", liquidationThreshold: 82.5 }, // Token address is token from priceFeed map above
      { symbol: "yvCurve_FRAX", liquidationThreshold: 90 }, // Token address is token from priceFeed map above

      { symbol: "CVX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "FXS", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "LQTY", liquidationThreshold: 0 },
      { symbol: "CRV", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "LDO", liquidationThreshold: 0 },
      { symbol: "SNX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
    ],
    uniV2Pairs: standardUniV2Config,
    uniV3Pools: standardUniV3Config,
    sushiswapPairs: standardSushiswapConfig,
    adapters,
  },
  {
    symbol: "OHM",
    minAmount: BigNumber.from(10).pow(9).mul(15000),
    maxAmount: BigNumber.from(10).pow(9).mul(100000),
    collateralTokens: [
      // Liquidation threshold will be multiplied x100 to be used as CreditFilter.sol contract parameter

      { symbol: "WETH", liquidationThreshold: 75 }, // Token address is token from priceFeed map above
      { symbol: "WBTC", liquidationThreshold: 75 }, // Token address is token from priceFeed map above

      { symbol: "USDC", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "USDT", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "sUSD", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "DAI", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "GUSD", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "LUSD", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "FRAX", liquidationThreshold: 85 },
      { symbol: "MIM", liquidationThreshold: 80 },

      { symbol: "3Crv", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "cvx3Crv", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "stkcvx3Crv", liquidationThreshold: 85 },

      { symbol: "FRAX3CRV", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "cvxFRAX3CRV", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxFRAX3CRV", liquidationThreshold: 85 },

      { symbol: "LUSD3CRV", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "cvxLUSD3CRV", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxLUSD3CRV", liquidationThreshold: 85 },

      { symbol: "crvPlain3andSUSD", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvPlain3andSUSD", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvPlain3andSUSD", liquidationThreshold: 85 },

      { symbol: "gusd3CRV", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "cvxgusd3CRV", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxgusd3CRV", liquidationThreshold: 85 }, // Token address is token from priceFeed map above

      { symbol: "crvFRAX", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvFRAX", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvFRAX", liquidationThreshold: 85 }, // Token address is token from priceFeed map above

      { symbol: "OHMFRAXBP", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "cvxOHMFRAXBP", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxOHMFRAXBP", liquidationThreshold: 85 }, // Token address is token from priceFeed map above

      { symbol: "MIM_3LP3CRV", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "cvxMIM_3LP3CRV", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxMIM_3LP3CRV", liquidationThreshold: 85 }, // Token address is token from priceFeed map above

      { symbol: "CVX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "FXS", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "LQTY", liquidationThreshold: 0 },
      { symbol: "CRV", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "SNX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "SPELL", liquidationThreshold: 25 },
    ],
    uniV2Pairs: standardUniV2Config,
    uniV3Pools: standardUniV3Config,
    sushiswapPairs: [
      ...standardSushiswapConfig,
      { token0: "WETH", token1: "SPELL" },
    ],
    adapters: [
      /// SWAPPERS
      "UNISWAP_V3_ROUTER",
      "UNISWAP_V2_ROUTER",
      "SUSHISWAP_ROUTER",

      // CURVE
      "CURVE_3CRV_POOL",
      "CURVE_FRAX_USDC_POOL",
      "CURVE_FRAX_POOL",
      "CURVE_SUSD_POOL",
      "CURVE_LUSD_POOL",
      "CURVE_GUSD_POOL",
      "CURVE_SUSD_DEPOSIT",
      "CURVE_OHMFRAXBP_POOL",
      "CURVE_MIM_POOL",

      // CONVEX
      "CONVEX_FRAX3CRV_POOL",
      "CONVEX_LUSD3CRV_POOL",
      "CONVEX_GUSD_POOL",
      "CONVEX_SUSD_POOL",
      "CONVEX_3CRV_POOL",
      "CONVEX_FRAX_USDC_POOL",
      "CONVEX_OHMFRAXBP_POOL",
      "CONVEX_MIM3CRV_POOL",
      "CONVEX_BOOSTER",

      // BALANCER
      "BALANCER_VAULT",
    ],
    balancerPools: [
      {
        pool: "50OHM_50DAI",
        status: "SWAP_ONLY",
      },
      {
        pool: "50OHM_50WETH",
        status: "SWAP_ONLY",
      },
      {
        pool: "OHM_wstETH",
        status: "SWAP_ONLY",
      },
    ],
  },

  {
    symbol: "WETH",

    minAmount: BigInt(100) * WAD, // 0.3 WETH
    maxAmount: BigInt(600) * WAD, // 100WETH ~ 400K
    collateralTokens: [
      // Liquidation threshold will be multiplied x100 to be used as CreditFilter.sol contract parameter
      { symbol: "WBTC", liquidationThreshold: 85 }, // Token address is token from priceFeed map above
      { symbol: "USDT", liquidationThreshold: 85 }, // Token address is token from priceFeed map above

      { symbol: "crvUSDTWBTCWETH", liquidationThreshold: 88 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvUSDTWBTCWETH", liquidationThreshold: 88 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvUSDTWBTCWETH", liquidationThreshold: 88 }, // Token address is token from priceFeed map above

      { symbol: "crvCRVETH", liquidationThreshold: 82 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvCRVETH", liquidationThreshold: 82 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvCRVETH", liquidationThreshold: 82 }, // Token address is token from priceFeed map above

      { symbol: "crvCVXETH", liquidationThreshold: 82 }, // Token address is token from priceFeed map above
      { symbol: "cvxcrvCVXETH", liquidationThreshold: 82 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxcrvCVXETH", liquidationThreshold: 82 }, // Token address is token from priceFeed map above

      { symbol: "LDOETH", liquidationThreshold: 82 }, // Token address is token from priceFeed map above
      { symbol: "cvxLDOETH", liquidationThreshold: 82 }, // Token address is token from priceFeed map above
      { symbol: "stkcvxLDOETH", liquidationThreshold: 82 }, // Token address is token from priceFeed map above

      { symbol: "CVX", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "CRV", liquidationThreshold: 25 }, // Token address is token from priceFeed map above
      { symbol: "LDO", liquidationThreshold: 25 },
    ],
    adapters: [
      // CURVE
      "CURVE_3CRYPTO_POOL",
      "CURVE_CRVETH_POOL",
      "CURVE_CVXETH_POOL",
      "CURVE_LDOETH_POOL",

      // CONVEX
      "CONVEX_3CRYPTO_POOL",
      "CONVEX_CRVETH_POOL",
      "CONVEX_CVXETH_POOL",
      "CONVEX_LDOETH_POOL",
      "CONVEX_BOOSTER",
    ],
  },
];
