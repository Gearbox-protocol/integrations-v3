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

contract CONFIG_MAINNET_WETH_V3 is IPoolV3DeployConfig {
    string public constant id = "mainnet-weth-v3";
    uint256 public constant chainId = 1;
    Tokens public constant underlying = Tokens.WETH;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 50_000_000_000_000_000_000;

    // POOL

    string public constant symbol = "dWETHV3";
    string public constant name = "Trade WETH v3";

    PoolV3DeployParams _poolParams =
        PoolV3DeployParams({withdrawalFee: 0, totalDebtLimit: 50_000_000_000_000_000_000_000});

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
        _gaugeRates.push(GaugeRate({token: Tokens.WBTC, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.USDC, minRate: 4, maxRate: 12_00}));
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
        _gaugeRates.push(GaugeRate({token: Tokens.yvUSDC, minRate: 1, maxRate: 27_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvWBTC, minRate: 1, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.sDAI, minRate: 1, maxRate: 27_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.STETH, minRate: 5, maxRate: 3_50}));
        _gaugeRates.push(GaugeRate({token: Tokens.rETH, minRate: 5, maxRate: 3_16}));
        _gaugeRates.push(GaugeRate({token: Tokens.osETH, minRate: 5, maxRate: 3_16}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvWETH, minRate: 50, maxRate: 5_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvxcrvUSDTWBTCWETH, minRate: 1_00, maxRate: 7_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvxcrvUSDETHCRV, minRate: 1_00, maxRate: 14_70}));
        _gaugeRates.push(GaugeRate({token: Tokens.auraB_rETH_STABLE_vault, minRate: 1_00, maxRate: 5_50}));
        _gaugeRates.push(GaugeRate({token: Tokens.weETH, minRate: 5, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.ezETH, minRate: 5, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.rsETH, minRate: 5, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.pufETH, minRate: 5, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.rswETH, minRate: 5, maxRate: 30_00}));
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.WBTC, quotaIncreaseFee: 1, limit: 15_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.USDC, quotaIncreaseFee: 1, limit: 15_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.DAI, quotaIncreaseFee: 1, limit: 15_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.FRAX, quotaIncreaseFee: 1, limit: 15_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.USDT, quotaIncreaseFee: 1, limit: 15_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.MKR, quotaIncreaseFee: 1, limit: 135_000_000_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.UNI, quotaIncreaseFee: 1, limit: 135_000_000_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LINK, quotaIncreaseFee: 1, limit: 135_000_000_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LDO, quotaIncreaseFee: 1, limit: 135_000_000_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.CRV, quotaIncreaseFee: 1, limit: 55_000_000_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.CVX, quotaIncreaseFee: 1, limit: 55_000_000_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.FXS, quotaIncreaseFee: 1, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.APE, quotaIncreaseFee: 1, limit: 0}));
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.yvUSDC, quotaIncreaseFee: 1, limit: 15_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.yvWBTC, quotaIncreaseFee: 1, limit: 500_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.sDAI, quotaIncreaseFee: 1, limit: 15_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.STETH, quotaIncreaseFee: 0, limit: 15_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.rETH, quotaIncreaseFee: 0, limit: 15_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.osETH, quotaIncreaseFee: 0, limit: 15_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.yvWETH, quotaIncreaseFee: 0, limit: 15_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.stkcvxcrvUSDTWBTCWETH, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.stkcvxcrvUSDETHCRV, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.auraB_rETH_STABLE_vault, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.weETH, quotaIncreaseFee: 0, limit: 20_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.ezETH, quotaIncreaseFee: 0, limit: 40_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.rsETH, quotaIncreaseFee: 0, limit: 10_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.pufETH, quotaIncreaseFee: 0, limit: 10_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.rswETH, quotaIncreaseFee: 0, limit: 10_000_000_000_000_000_000_000})
        );

        {
            /// CREDIT_MANAGER_0
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 10_000_000_000_000_000_000;
            cp.maxDebt = 500_000_000_000_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 150;
            cp.liquidationPremium = 400;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 1_500_000_000_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.USDC, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.WBTC, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.DAI, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.USDT, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvUSDC, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvWBTC, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.sDAI, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvWETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.STETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens._3Crv, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDTWBTCWETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.steCRV, lt: 0}));
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
            cs.push(Contracts.CURVE_3CRV_POOL);
            cs.push(Contracts.CURVE_3CRYPTO_POOL);
            cs.push(Contracts.CURVE_STETH_GATEWAY);
            cs.push(Contracts.YEARN_USDC_VAULT);
            cs.push(Contracts.YEARN_WBTC_VAULT);
            cs.push(Contracts.YEARN_WETH_VAULT);
            cs.push(Contracts.MAKER_DSR_VAULT);
        }
        {
            /// CREDIT_MANAGER_1
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 10_000_000_000_000_000_000;
            cp.maxDebt = 250_000_000_000_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 150;
            cp.liquidationPremium = 400;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 1_500_000_000_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.USDC, lt: 90_00}));

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

            cp.minDebt = 10_000_000_000_000_000_000;
            cp.maxDebt = 100_000_000_000_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 150;
            cp.liquidationPremium = 400;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 1_500_000_000_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.USDC, lt: 90_00}));

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

            cp.minDebt = 25_000_000_000_000_000_000;
            cp.maxDebt = 500_000_000_000_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 150;
            cp.liquidationPremium = 400;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = true;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 2_500_000_000_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.WBTC, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.USDT, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.STETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.rETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.weETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.osETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvWETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.stkcvxcrvUSDETHCRV, lt: 85_00}));

            cts.push(CollateralTokenHuman({token: Tokens.stkcvxcrvUSDTWBTCWETH, lt: 85_00}));

            cts.push(CollateralTokenHuman({token: Tokens.auraB_rETH_STABLE_vault, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.CRV, lt: 72_50}));

            cts.push(CollateralTokenHuman({token: Tokens.CVX, lt: 72_50}));

            cts.push(CollateralTokenHuman({token: Tokens.BAL, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.AURA, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.SWISE, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDETHCRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.cvxcrvUSDETHCRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDTWBTCWETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.cvxcrvUSDTWBTCWETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.B_rETH_STABLE, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.auraB_rETH_STABLE, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.steCRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSD, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvCVXETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.rETH_f, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
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
                        token0: Tokens.WETH,
                        token1: Tokens.SWISE,
                        fee: 3000
                    })
                );
            }
            cs.push(Contracts.BALANCER_VAULT);
            BalancerPool[] storage bp = cp.balancerPools;

            bp.push(
                BalancerPool({poolId: 0x05ff47afada98a98982113758878f9a8b9fdda0a000000000000000000000645, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112, status: 1})
            );

            bp.push(
                BalancerPool({poolId: 0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0xcfca23ca9ca720b6e98e3eb9b6aa0ffc4a5c08b9000200000000000000000274, status: 2})
            );
            cs.push(Contracts.CURVE_CVXETH_POOL);
            cs.push(Contracts.CURVE_STETH_GATEWAY);
            cs.push(Contracts.CURVE_RETH_ETH_POOL);
            cs.push(Contracts.CURVE_TRI_CRV_POOL);
            cs.push(Contracts.CURVE_3CRYPTO_POOL);
            cs.push(Contracts.CONVEX_BOOSTER);
            cs.push(Contracts.CONVEX_TRI_CRV_POOL);
            cs.push(Contracts.CONVEX_3CRYPTO_POOL);
            cs.push(Contracts.AURA_BOOSTER);
            cs.push(Contracts.AURA_B_RETH_STABLE_POOL);
            cs.push(Contracts.YEARN_WETH_VAULT);
        }
        {
            /// CREDIT_MANAGER_4
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 25_000_000_000_000_000_000;
            cp.maxDebt = 500_000_000_000_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 100;
            cp.liquidationPremium = 300;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 30_000_000_000_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.weETH, lt: 91_50}));

            cts.push(CollateralTokenHuman({token: Tokens.ezETH, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.rsETH, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.pufETH, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.rswETH, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.STETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.wstETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.rETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.rETH_f, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.steCRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.pufETHwstE, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.pufETH,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.weETH,
                        token1: Tokens.WETH,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.rETH,
                        token1: Tokens.WETH,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.rETH,
                        token1: Tokens.WETH,
                        fee: 100
                    })
                );
            }
            cs.push(Contracts.PANCAKESWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.PANCAKESWAP_V3_ROUTER,
                        token0: Tokens.rswETH,
                        token1: Tokens.WETH,
                        fee: 500
                    })
                );
            }
            cs.push(Contracts.BALANCER_VAULT);
            BalancerPool[] storage bp = cp.balancerPools;

            bp.push(
                BalancerPool({poolId: 0x05ff47afada98a98982113758878f9a8b9fdda0a000000000000000000000645, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0x596192bb6e41802428ac943d2f1476c1af25cc0e000000000000000000000659, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0x848a5564158d84b8a8fb68ab5d004fae11619a5400000000000000000000066a, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0x58aadfb1afac0ad7fca1148f3cde6aedf5236b6d00000000000000000000067f, status: 2})
            );
            cs.push(Contracts.CURVE_RETH_ETH_POOL);
            cs.push(Contracts.CURVE_PUFETH_WSTETH_POOL);
            cs.push(Contracts.CURVE_STETH_GATEWAY);
            cs.push(Contracts.LIDO_WSTETH);
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
