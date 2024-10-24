// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";
import {
    LinearIRMV3DeployParams,
    PoolV3DeployParams,
    CreditManagerV3DeployParams,
    GaugeRate,
    PoolQuotaLimit,
    IPoolV3DeployConfig,
    CollateralTokenHuman,
    GenericSwapPair,
    UniswapV3Pair,
    BalancerPool,
    VelodromeV2Pool,
    PendlePair,
    MellowUnderlyingConfig
} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";

contract CONFIG_MAINNET_WETH_TEST_V3 is IPoolV3DeployConfig {
    string public constant id = "mainnet-weth-test-v3";
    uint256 public constant chainId = 1;
    Tokens public constant underlying = Tokens.WETH;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 50_000_000_000_000_000_000;

    // POOL

    string public constant symbol = "dWETH-test-V3";
    string public constant name = "Test WETH v3";

    PoolV3DeployParams _poolParams =
        PoolV3DeployParams({withdrawalFee: 0, totalDebtLimit: 100_000_000_000_000_000_000_000});

    LinearIRMV3DeployParams _irm = LinearIRMV3DeployParams({
        U_1: 7_000,
        U_2: 9_000,
        R_base: 0,
        R_slope1: 100,
        R_slope2: 125,
        R_slope3: 10_000,
        _isBorrowingMoreU2Forbidden: true
    });

    GaugeRate[] _gaugeRates;
    PoolQuotaLimit[] _quotaLimits;

    CreditManagerV3DeployParams[] _creditManagers;

    constructor() {
        _gaugeRates.push(GaugeRate({token: Tokens.LDO, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.CRV, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.CVX, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.steCRV, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.cvxsteCRV, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.rsETH_WETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.trenSTETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.Re7LRT, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.rstETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.amphrETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.STETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvxsteCRV, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.wstETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.steakLRT, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.rsETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.PT_rsETH_26SEP2024, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.USDC, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.WBTC, minRate: 4, maxRate: 1_500}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LDO, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.CRV, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.CVX, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.steCRV, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.cvxsteCRV, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.rsETH_WETH, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.trenSTETH, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.Re7LRT, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.rstETH, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.amphrETH, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.STETH, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.stkcvxsteCRV, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.wstETH, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.steakLRT, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.rsETH, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.PT_rsETH_26SEP2024, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.USDC, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.WBTC, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );

        {
            /// CREDIT_MANAGER_0
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 20_000_000_000_000_000_000;
            cp.maxDebt = 400_000_000_000_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 150;
            cp.liquidationPremium = 400;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 5_000_000_000_000_000_000_000;
            cp.maxEnabledTokens = 4;
            cp.name = "Test Credit Manager";

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.USDC, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.WBTC, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.STETH, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.wstETH, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.steakLRT, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.rsETH, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.PT_rsETH_26SEP2024, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.stkcvxsteCRV, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.steCRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.cvxsteCRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.rsETH_WETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.trenSTETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.Re7LRT, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.rstETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.amphrETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.LDO, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.CRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.CVX, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.adapterConfig.uniswapV3Pairs;
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.WBTC,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.USDC,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.CRV,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.CRV,
                        fee: 10000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.CVX,
                        fee: 10000
                    })
                );
            }
            cs.push(Contracts.PENDLE_ROUTER);
            PendlePair[] storage pendp = cp.adapterConfig.pendlePairs;
            pendp.push(
                PendlePair({
                    market: 0x6b4740722e46048874d84306B2877600ABCea3Ae,
                    inputToken: Tokens.rsETH,
                    pendleToken: Tokens.PT_rsETH_26SEP2024,
                    status: 1
                })
            );
            cs.push(Contracts.BALANCER_VAULT);
            BalancerPool[] storage bp = cp.adapterConfig.balancerPools;

            bp.push(
                BalancerPool({poolId: 0x58aadfb1afac0ad7fca1148f3cde6aedf5236b6d00000000000000000000067f, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0x4216d5900a6109bba48418b5e2ab6cc4e61cf4770000000000000000000006a1, status: 2})
            );
            cs.push(Contracts.MELLOW_STEAKHOUSE_VAULT);
            {
                MellowUnderlyingConfig[] storage mu = cp.adapterConfig.mellowUnderlyings;
                mu.push(MellowUnderlyingConfig({vault: Contracts.MELLOW_STEAKHOUSE_VAULT, underlying: Tokens.wstETH}));
            }
            cs.push(Contracts.LIDO_WSTETH);
            cs.push(Contracts.CURVE_STETH_GATEWAY);
            cs.push(Contracts.CONVEX_BOOSTER);
            cs.push(Contracts.CONVEX_STECRV_POOL);
        }
    }

    // GETTERS

    function poolParams() external view override returns (PoolV3DeployParams memory) {
        return _poolParams;
    }

    function irm() external view override returns (LinearIRMV3DeployParams memory) {
        return _irm;
    }

    function gaugeRates() external view override returns (GaugeRate[] memory) {
        return _gaugeRates;
    }

    function quotaLimits() external view override returns (PoolQuotaLimit[] memory) {
        return _quotaLimits;
    }

    function creditManagers() external view override returns (CreditManagerV3DeployParams[] memory) {
        return _creditManagers;
    }
}
