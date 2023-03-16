/*
 * Copyright (c) 2022. Gearbox
 */
import { WAD } from "@gearbox-protocol/sdk";
import { BigNumber } from "ethers";

import { CMConfig } from "../core/pool";
import { adapters } from "./adapters";

export const mainnetCreditManagers: Array<CMConfig> = [
  {
    symbol: "DAI",
    minAmount: WAD.mul(150000),
    maxAmount: WAD.mul(1000000), // maxBorrowAmount = 10K + 3 x 10K = 40K
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
    adapters,
  },
  {
    symbol: "USDC",
    minAmount: WAD.mul(150000).div(BigNumber.from(10).pow(12)),
    maxAmount: WAD.mul(1000000).div(BigNumber.from(10).pow(12)), // maxBorrowAmount = 10K + 3 x 10K = 40K
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
    adapters,
  },

  {
    symbol: "WETH",

    minAmount: WAD.mul(100), // 0.3 WETH
    maxAmount: WAD.mul(600), // 100WETH ~ 400K
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
    adapters,
  },

  {
    symbol: "wstETH",

    minAmount: WAD.mul(100), // 0.3 WETH
    maxAmount: WAD.mul(600), // 100WETH ~ 400K
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
    adapters,
  },
];
