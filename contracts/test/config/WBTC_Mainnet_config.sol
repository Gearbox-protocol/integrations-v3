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

contract CONFIG_MAINNET_WBTC_V3 is IPoolV3DeployConfig {
    string public constant id = "mainnet-wbtc-v3";
    uint256 public constant chainId = 1;
    Tokens public constant underlying = Tokens.WBTC;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 250_000_000;

    // POOL

    string public constant symbol = "dWBTCV3";
    string public constant name = "Trade WBTC v3";

    PoolV3DeployParams _poolParams = PoolV3DeployParams({withdrawalFee: 0, totalDebtLimit: 250_000_000_000});

    LinearIRMV3DeployParams _irm = LinearIRMV3DeployParams({
        U_1: 70_00,
        U_2: 90_00,
        R_base: 0,
        R_slope1: 2_00,
        R_slope2: 2_50,
        R_slope3: 60_00,
        _isBorrowingMoreU2Forbidden: true
    });

    GaugeRate[] _gaugeRates;
    PoolQuotaLimit[] _quotaLimits;

    CreditManagerV3DeployParams[] _creditManagers;

    constructor() {
        _gaugeRates.push(GaugeRate({token: Tokens.USDC, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.WETH, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.STETH, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.DAI, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.FRAX, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.USDT, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.MKR, minRate: 80, maxRate: 24_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.UNI, minRate: 80, maxRate: 24_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.LINK, minRate: 80, maxRate: 24_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.LDO, minRate: 80, maxRate: 24_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.CRV, minRate: 2_40, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.CVX, minRate: 2_40, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.FXS, minRate: 2_40, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.APE, minRate: 2_40, maxRate: 40_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvWETH, minRate: 1, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvUSDC, minRate: 1, maxRate: 27_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.sDAI, minRate: 1, maxRate: 27_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvWBTC, minRate: 1, maxRate: 15_00}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.USDC, quotaIncreaseFee: 1, limit: 75_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WETH, quotaIncreaseFee: 1, limit: 75_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.STETH, quotaIncreaseFee: 1, limit: 75_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.DAI, quotaIncreaseFee: 1, limit: 75_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.FRAX, quotaIncreaseFee: 1, limit: 75_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.USDT, quotaIncreaseFee: 1, limit: 75_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.MKR, quotaIncreaseFee: 1, limit: 750_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.UNI, quotaIncreaseFee: 1, limit: 750_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LINK, quotaIncreaseFee: 1, limit: 750_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LDO, quotaIncreaseFee: 1, limit: 750_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.CRV, quotaIncreaseFee: 1, limit: 300_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.CVX, quotaIncreaseFee: 1, limit: 300_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.FXS, quotaIncreaseFee: 1, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.APE, quotaIncreaseFee: 1, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvWETH, quotaIncreaseFee: 1, limit: 75_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvUSDC, quotaIncreaseFee: 1, limit: 10_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.sDAI, quotaIncreaseFee: 1, limit: 75_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvWBTC, quotaIncreaseFee: 0, limit: 2_500_000_000}));

        {
            /// CREDIT_MANAGER_0
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 50_000_000;
            cp.maxDebt = 2_500_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 150;
            cp.liquidationPremium = 400;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 7_500_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.USDC, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.USDT, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.STETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.DAI, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvWETH, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.sDAI, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvUSDC, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvWBTC, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens._3Crv, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDTWBTCWETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.steCRV, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V2_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.adapterConfig.genericSwapPairs;
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
                UniswapV3Pair[] storage uv3p = cp.adapterConfig.uniswapV3Pairs;
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
            }
            cs.push(Contracts.SUSHISWAP_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.adapterConfig.genericSwapPairs;
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
            cs.push(Contracts.CURVE_3CRV_POOL);
            cs.push(Contracts.CURVE_3CRYPTO_POOL);
            cs.push(Contracts.CURVE_STETH_GATEWAY);
            cs.push(Contracts.YEARN_WETH_VAULT);
            cs.push(Contracts.YEARN_USDC_VAULT);
            cs.push(Contracts.YEARN_WBTC_VAULT);
            cs.push(Contracts.MAKER_DSR_VAULT);
        }
        {
            /// CREDIT_MANAGER_1
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 50_000_000;
            cp.maxDebt = 1_250_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 150;
            cp.liquidationPremium = 400;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 7_500_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.USDC, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.DAI, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.USDT, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.MKR, lt: 82_50}));

            cts.push(CollateralTokenHuman({token: Tokens.UNI, lt: 82_50}));

            cts.push(CollateralTokenHuman({token: Tokens.LINK, lt: 82_50}));

            cts.push(CollateralTokenHuman({token: Tokens.LDO, lt: 82_50}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDTWBTCWETH, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V2_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.adapterConfig.genericSwapPairs;
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
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.WBTC, token1: Tokens.WETH})
                );
            }
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.adapterConfig.uniswapV3Pairs;
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
                        token0: Tokens.WBTC,
                        token1: Tokens.WETH,
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
                        token0: Tokens.WBTC,
                        token1: Tokens.USDT,
                        fee: 3000
                    })
                );
            }
            cs.push(Contracts.SUSHISWAP_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.adapterConfig.genericSwapPairs;
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
                gsp.push(
                    GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.WBTC, token1: Tokens.WETH})
                );
            }
            cs.push(Contracts.CURVE_3CRYPTO_POOL);
        }
        {
            /// CREDIT_MANAGER_2
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 50_000_000;
            cp.maxDebt = 500_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 150;
            cp.liquidationPremium = 400;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 7_500_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.USDC, lt: 90_00}));

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

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDTWBTCWETH, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V2_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.adapterConfig.genericSwapPairs;
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
                gsp.push(
                    GenericSwapPair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.WBTC, token1: Tokens.WETH})
                );
            }
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.adapterConfig.uniswapV3Pairs;
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
                        token0: Tokens.WBTC,
                        token1: Tokens.WETH,
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
                        token0: Tokens.WBTC,
                        token1: Tokens.USDT,
                        fee: 3000
                    })
                );
            }
            cs.push(Contracts.SUSHISWAP_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.adapterConfig.genericSwapPairs;
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
                gsp.push(
                    GenericSwapPair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.WBTC, token1: Tokens.WETH})
                );
            }
            cs.push(Contracts.FRAXSWAP_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.adapterConfig.genericSwapPairs;
                gsp.push(GenericSwapPair({router: Contracts.FRAXSWAP_ROUTER, token0: Tokens.FRAX, token1: Tokens.FXS}));
                gsp.push(GenericSwapPair({router: Contracts.FRAXSWAP_ROUTER, token0: Tokens.FRAX, token1: Tokens.WETH}));
            }
            cs.push(Contracts.CURVE_CVXETH_POOL);
            cs.push(Contracts.CURVE_TRI_CRV_POOL);
            cs.push(Contracts.CURVE_3CRYPTO_POOL);
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
