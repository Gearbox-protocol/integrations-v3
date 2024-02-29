import {
  BalancerVaultConfig,
  CreditManagerV3DeployConfig,
  GenericSwapConfig,
  PoolV3DeployConfig,
  UniV3Config,
  VelodromeV2Config,
} from "@gearbox-protocol/sdk-gov";

const POOL_DECIMALS = BigInt(1e18);

const levCamelotV3Config: GenericSwapConfig = {
  contract: "CAMELOT_V3_ROUTER",
  allowed: [{ token0: "WETH", token1: "USDC" }],
};

const levCreditManager: CreditManagerV3DeployConfig = {
  name: "Test Credit Manager",
  degenNft: false,
  expirationDate: undefined,
  minDebt: (BigInt(35) * POOL_DECIMALS) / BigInt(100),
  maxDebt: BigInt(150) * POOL_DECIMALS,
  feeInterest: 2500,
  feeLiquidation: 50,
  liquidationPremium: 100,
  feeLiquidationExpired: 50,
  liquidationPremiumExpired: 100,
  poolLimit: BigInt(1000) * POOL_DECIMALS,
  collateralTokens: [
    {
      token: "USDC",
      lt: 9400,
    },
  ],
  adapters: [levCamelotV3Config],
};

export const config: PoolV3DeployConfig = {
  id: "arbitrum-weth-test-v3",
  symbol: "dWETH-test-V3",
  name: "Test WETH v3",
  network: "Arbitrum",
  underlying: "WETH",
  accountAmount: BigInt(10) * POOL_DECIMALS,
  withdrawalFee: 0,
  totalDebtLimit: BigInt(150_000) * POOL_DECIMALS,
  irm: {
    U1: 7000,
    U2: 9000,
    Rbase: 0,
    Rslope1: 200,
    Rslope2: 250,
    Rslope3: 6000,
    isBorrowingMoreU2Forbidden: true,
  },
  ratesAndLimits: {
    // TRADEABLE TOKENS
    USDC: {
      minRate: 4,
      maxRate: 1200,
      quotaIncreaseFee: 1,
      limit: BigInt(2000) * POOL_DECIMALS,
    },
  },
  creditManagers: [levCreditManager],
  supportsQuotas: true,
};
