// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
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
    uint256 public constant underlying = TOKEN_WETH;
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
        _gaugeRates.push(GaugeRate({token: TOKEN_LDO, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_CRV, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_CVX, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_steCRV, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_cvxsteCRV, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_rsETH_WETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_trenSTETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_Re7LRT, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_rstETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_amphrETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_STETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_stkcvxsteCRV, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_wstETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_steakLRT, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_rsETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_PT_rsETH_26SEP2024, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_USDC, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_WBTC, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_pufETHwstE, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_pufETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_zpufETH, minRate: 4, maxRate: 1_500}));
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_LDO, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_CRV, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_CVX, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_steCRV, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_cvxsteCRV, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_rsETH_WETH, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_trenSTETH, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_Re7LRT, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_rstETH, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_amphrETH, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(
            PoolQuotaLimit({token: TOKEN_STETH, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: TOKEN_stkcvxsteCRV, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: TOKEN_wstETH, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: TOKEN_steakLRT, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: TOKEN_rsETH, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: TOKEN_PT_rsETH_26SEP2024, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: TOKEN_USDC, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: TOKEN_WBTC, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_pufETHwstE, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(
            PoolQuotaLimit({token: TOKEN_pufETH, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: TOKEN_zpufETH, quotaIncreaseFee: 0, limit: 4_000_000_000_000_000_000_000})
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
            cts.push(CollateralTokenHuman({token: TOKEN_USDC, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: TOKEN_WBTC, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: TOKEN_STETH, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: TOKEN_wstETH, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: TOKEN_steakLRT, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: TOKEN_rsETH, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: TOKEN_PT_rsETH_26SEP2024, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: TOKEN_stkcvxsteCRV, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: TOKEN_pufETH, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: TOKEN_zpufETH, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: TOKEN_steCRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: TOKEN_cvxsteCRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: TOKEN_rsETH_WETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: TOKEN_trenSTETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: TOKEN_Re7LRT, lt: 0}));

            cts.push(CollateralTokenHuman({token: TOKEN_rstETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: TOKEN_amphrETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: TOKEN_LDO, lt: 0}));

            cts.push(CollateralTokenHuman({token: TOKEN_CRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: TOKEN_CVX, lt: 0}));

            cts.push(CollateralTokenHuman({token: TOKEN_pufETHwstE, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.adapterConfig.uniswapV3Pairs;
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: TOKEN_WETH,
                        token1: TOKEN_WBTC,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: TOKEN_WETH,
                        token1: TOKEN_USDC,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: TOKEN_WETH,
                        token1: TOKEN_CRV,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: TOKEN_WETH,
                        token1: TOKEN_CRV,
                        fee: 10000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: TOKEN_WETH,
                        token1: TOKEN_CVX,
                        fee: 10000
                    })
                );
            }
            cs.push(Contracts.PENDLE_ROUTER);
            PendlePair[] storage pendp = cp.adapterConfig.pendlePairs;
            pendp.push(
                PendlePair({
                    market: 0x6b4740722e46048874d84306B2877600ABCea3Ae,
                    inputToken: TOKEN_rsETH,
                    pendleToken: TOKEN_PT_rsETH_26SEP2024,
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
                mu.push(MellowUnderlyingConfig({vault: Contracts.MELLOW_STEAKHOUSE_VAULT, underlying: TOKEN_wstETH}));
            }
            cs.push(Contracts.LIDO_WSTETH);
            cs.push(Contracts.CURVE_STETH_GATEWAY);
            cs.push(Contracts.CURVE_PUFETH_WSTETH_POOL);
            cs.push(Contracts.CONVEX_BOOSTER);
            cs.push(Contracts.CONVEX_STECRV_POOL);
            cs.push(Contracts.ZIRCUIT_POOL);
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
