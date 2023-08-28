import {
  AdapterDeployConfig,
  BalancerVaultConfig,
  UniV2Config,
  UniV3Config,
} from "@gearbox-protocol/sdk-gov/lib/state/adapters";

const standardUniV2Config: UniV2Config = {
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

const standardUniV3Config: UniV3Config = {
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
  ],
};

const standardSushiswapConfig: UniV2Config = {
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

const standardBalancerConfig: BalancerVaultConfig = {
  contract: "BALANCER_V2_VAULT",
  allowed: [
    {
      pool: "50OHM_50DAI",
      status: 2,
    },
  ],
};

export const adapters: Array<AdapterDeployConfig> = [
  /// SWAPPERS
  standardUniV3Config,
  standardUniV2Config,
  standardSushiswapConfig,
  // CURVE
  { contract: "CURVE_3CRV_POOL" },
  { contract: "CURVE_FRAX_USDC_POOL" },
  { contract: "CURVE_STETH_GATEWAY" },
  { contract: "CURVE_FRAX_POOL" },
  { contract: "CURVE_SUSD_POOL" },
  { contract: "CURVE_LUSD_POOL" },
  { contract: "CURVE_GUSD_POOL" },
  { contract: "CURVE_SUSD_DEPOSIT" },

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
];
