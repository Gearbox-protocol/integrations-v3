import { AdapterDeployConfig } from "@gearbox-protocol/sdk-gov/lib/state/adapters";

export const adapters: Array<AdapterDeployConfig> = [
  /// SWAPPERS
  {
    contract: "UNISWAP_V3_ROUTER",
    allowed: [{ token0: "WETH", token1: "USDC", fee: 500 }],
  },
  {
    contract: "UNISWAP_V2_ROUTER",
    allowed: [{ token0: "WETH", token1: "USDC" }],
  },
  { contract: "SUSHISWAP_ROUTER" },
  { contract: "LIDO_STETH_GATEWAY" },

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
