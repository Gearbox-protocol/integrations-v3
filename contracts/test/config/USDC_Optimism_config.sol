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
    VelodromeV2Pool
} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";

contract CONFIG_OPTIMISM_USDC_V3 is IPoolV3DeployConfig {
    string public constant id = "optimism-usdc-v3";
    uint256 public constant chainId = 10;
    Tokens public constant underlying = Tokens.USDC_e;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 10_000_000_000;

    // POOL

    string public constant symbol = "dUSDCV3";
    string public constant name = "Main USDC.e v3";

    PoolV3DeployParams _poolParams = PoolV3DeployParams({withdrawalFee: 0, totalDebtLimit: 100_000_000_000_000});

    LinearIRMV3DeployParams _irm = LinearIRMV3DeployParams({
        U_1: 70_00,
        U_2: 90_00,
        R_base: 0,
        R_slope1: 1_00,
        R_slope2: 1_25,
        R_slope3: 100_00,
        _isBorrowingMoreU2Forbidden: true
    });

    GaugeRate[] _gaugeRates;
    PoolQuotaLimit[] _quotaLimits;

    CreditManagerV3DeployParams[] _creditManagers;

    constructor() {
        _gaugeRates.push(GaugeRate({token: Tokens.DAI, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.USDT, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.WBTC, minRate: 4, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.WETH, minRate: 4, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.OP, minRate: 4, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.WLD, minRate: 80, maxRate: 50_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.SNX, minRate: 80, maxRate: 50_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvWETH, minRate: 4, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.wstETH, minRate: 4, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.rETH, minRate: 4, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvDAI, minRate: 5, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvUSDC_e, minRate: 5, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvUSDT, minRate: 5, maxRate: 15_00}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.DAI, quotaIncreaseFee: 1, limit: 3_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.USDT, quotaIncreaseFee: 1, limit: 1_500_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WBTC, quotaIncreaseFee: 1, limit: 300_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WETH, quotaIncreaseFee: 1, limit: 1_500_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.OP, quotaIncreaseFee: 1, limit: 1_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WLD, quotaIncreaseFee: 5, limit: 600_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.SNX, quotaIncreaseFee: 5, limit: 300_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvWETH, quotaIncreaseFee: 1, limit: 500_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.wstETH, quotaIncreaseFee: 1, limit: 1_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.rETH, quotaIncreaseFee: 1, limit: 800_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvDAI, quotaIncreaseFee: 0, limit: 230_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvUSDC_e, quotaIncreaseFee: 0, limit: 330_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvUSDT, quotaIncreaseFee: 0, limit: 230_000_000_000}));

        {
            /// CREDIT_MANAGER_0
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 1_000_000_000;
            cp.maxDebt = 200_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 100;
            cp.liquidationPremium = 200;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 2_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.DAI, lt: 96_00}));

            cts.push(CollateralTokenHuman({token: Tokens.USDT, lt: 96_00}));

            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 94_00}));

            cts.push(CollateralTokenHuman({token: Tokens.WBTC, lt: 94_00}));

            cts.push(CollateralTokenHuman({token: Tokens.OP, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvWETH, lt: 94_00}));

            cts.push(CollateralTokenHuman({token: Tokens.wstETH, lt: 94_00}));

            cts.push(CollateralTokenHuman({token: Tokens.rETH, lt: 94_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvUSDC_e, lt: 94_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvDAI, lt: 94_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvUSDT, lt: 94_00}));

            cts.push(CollateralTokenHuman({token: Tokens._3CRV, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.adapterConfig.uniswapV3Pairs;
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.OP,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.USDC_e,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.USDC_e,
                        fee: 3000
                    })
                );
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
                        token0: Tokens.wstETH,
                        token1: Tokens.WETH,
                        fee: 100
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.WBTC,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.OP,
                        token1: Tokens.USDC_e,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.OP,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC_e,
                        token1: Tokens.USDT,
                        fee: 100
                    })
                );
            }
            cs.push(Contracts.BALANCER_VAULT);
            BalancerPool[] storage bp = cp.adapterConfig.balancerPools;

            bp.push(
                BalancerPool({poolId: 0x4fd63966879300cafafbb35d157dc5229278ed2300020000000000000000002b, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0x7ca75bdea9dede97f8b13c6641b768650cb837820002000000000000000000d5, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0x39965c9dab5448482cf7e002f583c812ceb53046000100000000000000000003, status: 2})
            );
            cs.push(Contracts.VELODROME_V2_ROUTER);
            VelodromeV2Pool[] storage vv2p = cp.adapterConfig.velodromeV2Pools;
            vv2p.push(
                VelodromeV2Pool({
                    token0: Tokens.wstETH,
                    token1: Tokens.WETH,
                    stable: false,
                    factory: 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a
                })
            );
            vv2p.push(
                VelodromeV2Pool({
                    token0: Tokens.WETH,
                    token1: Tokens.OP,
                    stable: false,
                    factory: 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a
                })
            );
            vv2p.push(
                VelodromeV2Pool({
                    token0: Tokens.OP,
                    token1: Tokens.USDC_e,
                    stable: false,
                    factory: 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a
                })
            );
            vv2p.push(
                VelodromeV2Pool({
                    token0: Tokens.WETH,
                    token1: Tokens.USDC_e,
                    stable: false,
                    factory: 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a
                })
            );
            vv2p.push(
                VelodromeV2Pool({
                    token0: Tokens.wstETH,
                    token1: Tokens.OP,
                    stable: false,
                    factory: 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a
                })
            );
            vv2p.push(
                VelodromeV2Pool({
                    token0: Tokens.USDC_e,
                    token1: Tokens.DAI,
                    stable: true,
                    factory: 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a
                })
            );
            vv2p.push(
                VelodromeV2Pool({
                    token0: Tokens.USDC_e,
                    token1: Tokens.USDT,
                    stable: true,
                    factory: 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a
                })
            );
            cs.push(Contracts.CURVE_3CRV_POOL_OP);
            cs.push(Contracts.YEARN_WETH_VAULT);
            cs.push(Contracts.YEARN_DAI_VAULT);
            cs.push(Contracts.YEARN_USDC_E_VAULT);
            cs.push(Contracts.YEARN_USDT_VAULT);
        }
        {
            /// CREDIT_MANAGER_1
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 1_000_000_000;
            cp.maxDebt = 50_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 100;
            cp.liquidationPremium = 200;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 500_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 94_00}));

            cts.push(CollateralTokenHuman({token: Tokens.WLD, lt: 85_00}));

            cts.push(CollateralTokenHuman({token: Tokens.SNX, lt: 85_00}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.adapterConfig.uniswapV3Pairs;
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.USDC_e,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.USDC_e,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC_e,
                        token1: Tokens.WLD,
                        fee: 10000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.WLD,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.SNX,
                        fee: 3000
                    })
                );
            }
            cs.push(Contracts.VELODROME_V2_ROUTER);
            VelodromeV2Pool[] storage vv2p = cp.adapterConfig.velodromeV2Pools;
            vv2p.push(
                VelodromeV2Pool({
                    token0: Tokens.WETH,
                    token1: Tokens.USDC_e,
                    stable: false,
                    factory: 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a
                })
            );
            vv2p.push(
                VelodromeV2Pool({
                    token0: Tokens.USDC_e,
                    token1: Tokens.SNX,
                    stable: false,
                    factory: 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a
                })
            );
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
