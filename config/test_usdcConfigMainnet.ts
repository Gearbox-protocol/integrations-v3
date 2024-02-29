import {
  BalancerVaultConfig,
  CreditManagerV3DeployConfig,
  GenericSwapConfig,
  PoolV3DeployConfig,
  UniV3Config,
} from "@gearbox-protocol/sdk-gov";

const POOL_DECIMALS = BigInt(1e6);
const POOL_DIVIDER = BigInt(1);

const levCreditManager: CreditManagerV3DeployConfig = {
  name: "Test Credit Manager",
  degenNft: false,
  expirationDate: undefined,
  minDebt: (BigInt(5e4) * POOL_DECIMALS) / POOL_DIVIDER,
  maxDebt: (BigInt(1e6) * POOL_DECIMALS) / POOL_DIVIDER,
  feeInterest: 2500,
  feeLiquidation: 150,
  liquidationPremium: 400,
  feeLiquidationExpired: 100,
  liquidationPremiumExpired: 200,
  poolLimit: (BigInt(5e6) * POOL_DECIMALS) / POOL_DIVIDER,
  collateralTokens: [
    {
      token: "USDe",
      lt: 9000,
    },
    // Compatibility
    {
      token: "USDeUSDC",
      lt: 0,
    },
  ],
  adapters: [
    {
      contract: "CURVE_USDE_USDC_POOL",
    },
  ],
};

export const config: PoolV3DeployConfig = {
  id: "mainnet-usdc-test-v3",
  symbol: "dUSDC-test-V3",
  name: "Test USDC v3",
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
    USDe: {
      minRate: 4,
      maxRate: 1500,
      quotaIncreaseFee: 1,
      limit: (BigInt(10e6) * POOL_DECIMALS) / POOL_DIVIDER,
    },
  },
  creditManagers: [levCreditManager],
  supportsQuotas: true,
};
