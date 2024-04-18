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

contract CONFIG_MAINNET_USDC_V3 is IPoolV3DeployConfig {
    string public constant id = "mainnet-usdc-v3";
    uint256 public constant chainId = 1;
    Tokens public constant underlying = Tokens.USDC;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 100_000_000_000;

    // POOL

    string public constant symbol = "dUSDCV3";
    string public constant name = "Trade USDC v3";

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
        _gaugeRates.push(GaugeRate({token: Tokens.WBTC, minRate: 4, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.WETH, minRate: 4, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.DAI, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.FRAX, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.crvUSD, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.USDT, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.MKR, minRate: 80, maxRate: 50_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.UNI, minRate: 80, maxRate: 50_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.LINK, minRate: 80, maxRate: 50_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.LDO, minRate: 80, maxRate: 50_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.CRV, minRate: 2_40, maxRate: 50_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.CVX, minRate: 2_40, maxRate: 50_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.FXS, minRate: 2_40, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.APE, minRate: 2_40, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.sDAI, minRate: 5, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvUSDC, minRate: 50, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvDAI, minRate: 50, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvxcrvUSDUSDC, minRate: 1_00, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvxcrvUSDUSDT, minRate: 1_00, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvxcrvUSDFRAX, minRate: 1_00, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvxcrvFRAX, minRate: 1_00, maxRate: 3_50}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvWETH, minRate: 1, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvWBTC, minRate: 1, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.STETH, minRate: 4, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.ezETH, minRate: 5, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.USDe, minRate: 5, maxRate: 50_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.sUSDe, minRate: 5, maxRate: 50_00}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WBTC, quotaIncreaseFee: 1, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WETH, quotaIncreaseFee: 1, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.DAI, quotaIncreaseFee: 1, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.FRAX, quotaIncreaseFee: 1, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.crvUSD, quotaIncreaseFee: 1, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.USDT, quotaIncreaseFee: 1, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.MKR, quotaIncreaseFee: 1, limit: 500_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.UNI, quotaIncreaseFee: 1, limit: 500_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LINK, quotaIncreaseFee: 1, limit: 500_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LDO, quotaIncreaseFee: 1, limit: 500_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.CRV, quotaIncreaseFee: 1, limit: 200_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.CVX, quotaIncreaseFee: 1, limit: 200_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.FXS, quotaIncreaseFee: 1, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.APE, quotaIncreaseFee: 1, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.sDAI, quotaIncreaseFee: 0, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvUSDC, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvDAI, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.stkcvxcrvUSDUSDC, quotaIncreaseFee: 0, limit: 9_600_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.stkcvxcrvUSDUSDT, quotaIncreaseFee: 0, limit: 7_800_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.stkcvxcrvUSDFRAX, quotaIncreaseFee: 0, limit: 4_500_000_000_000})
        );
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.stkcvxcrvFRAX, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvWETH, quotaIncreaseFee: 1, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvWBTC, quotaIncreaseFee: 1, limit: 1_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.STETH, quotaIncreaseFee: 1, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.ezETH, quotaIncreaseFee: 0, limit: 3_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.USDe, quotaIncreaseFee: 0, limit: 40_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.sUSDe, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));

        {
            /// CREDIT_MANAGER_0
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 20_000_000_000;
            cp.maxDebt = 1_000_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 150;
            cp.liquidationPremium = 400;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 30_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.WBTC, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.DAI, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.USDT, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.FRAX, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSD, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.STETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.ezETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvWETH, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvWBTC, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.USDe, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.sUSDe, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvUSDC, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvDAI, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.sDAI, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens._3Crv, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDTWBTCWETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.steCRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.USDeUSDC, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.FRAXUSDe, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.USDecrvUSD, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvFRAX, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDUSDC, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.USDeDAI, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.MtEthena, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V2_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.genericSwapPairs;
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.WETH, token1: Tokens.USDT})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.USDC, token1: Tokens.WETH})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.USDC, token1: Tokens.USDT})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.DAI, token1: Tokens.USDC})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.DAI, token1: Tokens.WETH})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.WBTC, token1: Tokens.WETH})
                );
            }
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.WETH,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WBTC,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.USDC,
                        fee: 100
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WBTC,
                        token1: Tokens.WETH,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.USDT,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.USDC,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WBTC,
                        token1: Tokens.USDC,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.USDT,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.USDT,
                        fee: 100
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.USDT,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.WETH,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WBTC,
                        token1: Tokens.USDT,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.WETH,
                        fee: 10000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDe,
                        token1: Tokens.USDT,
                        fee: 100
                    })
                );
            }
            cs.push(Contracts.SUSHISWAP_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.genericSwapPairs;
                gsp.push(
                    GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.WBTC, token1: Tokens.WETH})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.WETH, token1: Tokens.USDT})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.USDC, token1: Tokens.WETH})
                );
                gsp.push(GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.DAI, token1: Tokens.WETH}));
            }
            cs.push(Contracts.BALANCER_VAULT);
            BalancerPool[] storage bp = cp.balancerPools;

            bp.push(
                BalancerPool({poolId: 0x596192bb6e41802428ac943d2f1476c1af25cc0e000000000000000000000659, status: 2})
            );
            cs.push(Contracts.CURVE_3CRV_POOL);
            cs.push(Contracts.CURVE_3CRYPTO_POOL);
            cs.push(Contracts.CURVE_STETH_GATEWAY);
            cs.push(Contracts.CURVE_USDE_USDC_POOL);
            cs.push(Contracts.CURVE_USDE_DAI_POOL);
            cs.push(Contracts.CURVE_SDAI_SUSDE_POOL);
            cs.push(Contracts.CURVE_FRAX_USDE_POOL);
            cs.push(Contracts.CURVE_USDE_CRVUSD_POOL);
            cs.push(Contracts.CURVE_FRAX_USDC_POOL);
            cs.push(Contracts.CURVE_CRVUSD_USDC_POOL);
            cs.push(Contracts.YEARN_WETH_VAULT);
            cs.push(Contracts.YEARN_WBTC_VAULT);
            cs.push(Contracts.YEARN_USDC_VAULT);
            cs.push(Contracts.YEARN_DAI_VAULT);
            cs.push(Contracts.MAKER_DSR_VAULT);
            cs.push(Contracts.STAKED_USDE_VAULT);
        }
        {
            /// CREDIT_MANAGER_1
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 20_000_000_000;
            cp.maxDebt = 500_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 150;
            cp.liquidationPremium = 400;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 3_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.DAI, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.USDT, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.MKR, lt: 82_50}));

            cts.push(CollateralTokenHuman({token: Tokens.UNI, lt: 82_50}));

            cts.push(CollateralTokenHuman({token: Tokens.LINK, lt: 82_50}));

            cts.push(CollateralTokenHuman({token: Tokens.LDO, lt: 82_50}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V2_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.genericSwapPairs;
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.WETH, token1: Tokens.USDT})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.USDC, token1: Tokens.WETH})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.USDC, token1: Tokens.USDT})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.DAI, token1: Tokens.USDC})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.DAI, token1: Tokens.WETH})
                );
                gsp.push(GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.DAI, token1: Tokens.MKR}));
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.MKR, token1: Tokens.WETH})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.LINK, token1: Tokens.WETH})
                );
            }
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.WETH,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.USDC,
                        fee: 100
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.USDT,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.USDC,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.USDT,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.UNI,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.USDT,
                        fee: 100
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.MKR,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.LINK,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.MKR,
                        token1: Tokens.WETH,
                        fee: 10000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.USDT,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.WETH,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.LDO,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.WETH,
                        fee: 10000
                    })
                );
            }
            cs.push(Contracts.SUSHISWAP_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.genericSwapPairs;
                gsp.push(
                    GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.WETH, token1: Tokens.USDT})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.USDC, token1: Tokens.WETH})
                );
                gsp.push(GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.DAI, token1: Tokens.WETH}));
                gsp.push(GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.LDO, token1: Tokens.WETH}));
                gsp.push(
                    GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.LINK, token1: Tokens.WETH})
                );
            }
        }
        {
            /// CREDIT_MANAGER_2
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 20_000_000_000;
            cp.maxDebt = 200_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 150;
            cp.liquidationPremium = 400;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 3_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.DAI, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.USDT, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.FRAX, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.CRV, lt: 72_50}));

            cts.push(CollateralTokenHuman({token: Tokens.CVX, lt: 72_50}));

            cts.push(CollateralTokenHuman({token: Tokens.FXS, lt: 72_50}));

            cts.push(CollateralTokenHuman({token: Tokens.APE, lt: 72_50}));

            cts.push(CollateralTokenHuman({token: Tokens.crvCVXETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDETHCRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSD, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V2_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.genericSwapPairs;
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.WETH, token1: Tokens.USDT})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.USDC, token1: Tokens.WETH})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.USDC, token1: Tokens.USDT})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.DAI, token1: Tokens.USDC})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.DAI, token1: Tokens.WETH})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.FXS, token1: Tokens.FRAX})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.SNX, token1: Tokens.WETH})
                );
            }
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.WETH,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.USDC,
                        fee: 100
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.FRAX,
                        token1: Tokens.USDC,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.USDT,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.USDC,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.USDT,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.USDT,
                        fee: 100
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.FRAX,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.USDT,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.WETH,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.WETH,
                        fee: 10000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.APE,
                        token1: Tokens.WETH,
                        fee: 3000
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
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.FXS,
                        token1: Tokens.FRAX,
                        fee: 10000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.FXS,
                        token1: Tokens.FRAX,
                        fee: 10000
                    })
                );
            }
            cs.push(Contracts.SUSHISWAP_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.genericSwapPairs;
                gsp.push(
                    GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.WETH, token1: Tokens.USDT})
                );
                gsp.push(
                    GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.USDC, token1: Tokens.WETH})
                );
                gsp.push(GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.DAI, token1: Tokens.WETH}));
                gsp.push(GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.WETH, token1: Tokens.FXS}));
                gsp.push(GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.CVX, token1: Tokens.WETH}));
                gsp.push(GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.CRV, token1: Tokens.WETH}));
            }
            cs.push(Contracts.FRAXSWAP_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.genericSwapPairs;
                gsp.push(GenericSwapPair({router: Contracts.FRAXSWAP_ROUTER, token0: Tokens.FRAX, token1: Tokens.FXS}));
                gsp.push(GenericSwapPair({router: Contracts.FRAXSWAP_ROUTER, token0: Tokens.FRAX, token1: Tokens.WETH}));
            }
            cs.push(Contracts.CURVE_CVXETH_POOL);
            cs.push(Contracts.CURVE_TRI_CRV_POOL);
        }
        {
            /// CREDIT_MANAGER_3
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 50_000_000_000;
            cp.maxDebt = 1_000_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 150;
            cp.liquidationPremium = 400;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = true;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 5_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.DAI, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.USDT, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.FRAX, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.sDAI, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvUSDC, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvDAI, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.stkcvxcrvUSDUSDC, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.stkcvxcrvUSDUSDT, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.stkcvxcrvUSDFRAX, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.stkcvxcrvFRAX, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.CRV, lt: 72_50}));

            cts.push(CollateralTokenHuman({token: Tokens.CVX, lt: 72_50}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDUSDC, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.cvxcrvUSDUSDC, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDUSDT, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.cvxcrvUSDUSDT, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDFRAX, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.cvxcrvUSDFRAX, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvFRAX, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.cvxcrvFRAX, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens._3Crv, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvCVXETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDETHCRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSD, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.WETH,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.USDC,
                        fee: 100
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.FRAX,
                        token1: Tokens.USDC,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.USDT,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.USDC,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.USDT,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.USDT,
                        fee: 100
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.FRAX,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.USDT,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.DAI,
                        token1: Tokens.WETH,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.USDC,
                        token1: Tokens.WETH,
                        fee: 10000
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
            cs.push(Contracts.CURVE_CVXETH_POOL);
            cs.push(Contracts.CURVE_TRI_CRV_POOL);
            cs.push(Contracts.CURVE_3CRV_POOL);
            cs.push(Contracts.CURVE_FRAX_USDC_POOL);
            cs.push(Contracts.CURVE_CRVUSD_USDC_POOL);
            cs.push(Contracts.CURVE_CRVUSD_USDT_POOL);
            cs.push(Contracts.CURVE_CRVUSD_FRAX_POOL);
            cs.push(Contracts.CONVEX_BOOSTER);
            cs.push(Contracts.CONVEX_FRAX_USDC_POOL);
            cs.push(Contracts.CONVEX_CRVUSD_USDC_POOL);
            cs.push(Contracts.CONVEX_CRVUSD_USDT_POOL);
            cs.push(Contracts.CONVEX_CRVUSD_FRAX_POOL);
            cs.push(Contracts.YEARN_USDC_VAULT);
            cs.push(Contracts.YEARN_DAI_VAULT);
            cs.push(Contracts.MAKER_DSR_VAULT);
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
