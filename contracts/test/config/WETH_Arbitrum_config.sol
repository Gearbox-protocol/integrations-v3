// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.23;

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

contract CONFIG_ARBITRUM_WETH_V3 is IPoolV3DeployConfig {
    string public constant id = "arbitrum-weth-v3";
    uint256 public constant chainId = 42161;
    Tokens public constant underlying = Tokens.WETH;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 10_000_000_000_000_000_000;

    // POOL

    string public constant symbol = "dWETHV3";
    string public constant name = "Main WETH v3";

    PoolV3DeployParams _poolParams =
        PoolV3DeployParams({withdrawalFee: 0, totalDebtLimit: 150_000_000_000_000_000_000_000});

    LinearIRMV3DeployParams _irm = LinearIRMV3DeployParams({
        U_1: 7_000,
        U_2: 9_000,
        R_base: 0,
        R_slope1: 200,
        R_slope2: 250,
        R_slope3: 6_000,
        _isBorrowingMoreU2Forbidden: true
    });

    GaugeRate[] _gaugeRates;
    PoolQuotaLimit[] _quotaLimits;

    CreditManagerV3DeployParams[] _creditManagers;

    constructor() {
        _gaugeRates.push(GaugeRate({token: Tokens.USDC_e, minRate: 4, maxRate: 1_200}));
        _gaugeRates.push(GaugeRate({token: Tokens.USDC, minRate: 4, maxRate: 1_200}));
        _gaugeRates.push(GaugeRate({token: Tokens.WBTC, minRate: 4, maxRate: 1_200}));
        _gaugeRates.push(GaugeRate({token: Tokens.ARB, minRate: 4, maxRate: 2_400}));
        _gaugeRates.push(GaugeRate({token: Tokens.PENDLE, minRate: 80, maxRate: 2_400}));
        _gaugeRates.push(GaugeRate({token: Tokens.GMX, minRate: 80, maxRate: 2_400}));
        _gaugeRates.push(GaugeRate({token: Tokens.LINK, minRate: 80, maxRate: 2_400}));
        _gaugeRates.push(GaugeRate({token: Tokens.wstETH, minRate: 1, maxRate: 350}));
        _gaugeRates.push(GaugeRate({token: Tokens.rETH, minRate: 1, maxRate: 350}));
        _gaugeRates.push(GaugeRate({token: Tokens.cbETH, minRate: 1, maxRate: 350}));
        _gaugeRates.push(GaugeRate({token: Tokens.sfrxETH, minRate: 1, maxRate: 350}));
        _gaugeRates.push(GaugeRate({token: Tokens.ezETH, minRate: 5, maxRate: 3_000}));
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.USDC_e, quotaIncreaseFee: 1, limit: 2_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.USDC, quotaIncreaseFee: 1, limit: 2_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.WBTC, quotaIncreaseFee: 1, limit: 3_500_000_000_000_000_000_000})
        );
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.ARB, quotaIncreaseFee: 5, limit: 450_000_000_000_000_000_000}));
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.PENDLE, quotaIncreaseFee: 5, limit: 150_000_000_000_000_000_000})
        );
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.GMX, quotaIncreaseFee: 5, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LINK, quotaIncreaseFee: 5, limit: 0}));
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.wstETH, quotaIncreaseFee: 0, limit: 2_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.rETH, quotaIncreaseFee: 0, limit: 1_000_000_000_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.cbETH, quotaIncreaseFee: 0, limit: 500_000_000_000_000_000_000})
        );
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.sfrxETH, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.ezETH, quotaIncreaseFee: 0, limit: 0}));

        {
            /// CREDIT_MANAGER_0
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 350_000_000_000_000_000;
            cp.maxDebt = 150_000_000_000_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 50;
            cp.liquidationPremium = 100;
            cp.feeLiquidationExpired = 50;
            cp.liquidationPremiumExpired = 100;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 1_000_000_000_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.USDC_e, lt: 9_400}));

            cts.push(CollateralTokenHuman({token: Tokens.USDC, lt: 9_400}));

            cts.push(CollateralTokenHuman({token: Tokens.WBTC, lt: 9_400}));

            cts.push(CollateralTokenHuman({token: Tokens.ARB, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.wstETH, lt: 9_600}));

            cts.push(CollateralTokenHuman({token: Tokens.rETH, lt: 9_600}));

            cts.push(CollateralTokenHuman({token: Tokens.cbETH, lt: 9_600}));

            cts.push(CollateralTokenHuman({token: Tokens.ezETH, lt: 9_000}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
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
                        token1: Tokens.USDC,
                        fee: 500
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
                        token0: Tokens.WETH,
                        token1: Tokens.ARB,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.ARB,
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
                        token0: Tokens.ARB,
                        token1: Tokens.USDC_e,
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
            }
            cs.push(Contracts.BALANCER_VAULT);
            BalancerPool[] storage bp = cp.balancerPools;

            bp.push(
                BalancerPool({poolId: 0x9791d590788598535278552eecd4b211bfc790cb000000000000000000000498, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0xd0ec47c54ca5e20aaae4616c25c825c7f48d40690000000000000000000004ef, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0x2d6ced12420a9af5a83765a8c48be2afcd1a8feb000000000000000000000500, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0xb61371ab661b1acec81c699854d2f911070c059e000000000000000000000516, status: 2})
            );
            cs.push(Contracts.CAMELOT_V3_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.genericSwapPairs;
                gsp.push(
                    GenericSwapPair({router: Contracts.CAMELOT_V3_ROUTER, token0: Tokens.ezETH, token1: Tokens.WETH})
                );
            }
        }
        {
            /// CREDIT_MANAGER_1
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 350_000_000_000_000_000;
            cp.maxDebt = 35_000_000_000_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 100;
            cp.liquidationPremium = 200;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 500_000_000_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.USDC_e, lt: 9_400}));

            cts.push(CollateralTokenHuman({token: Tokens.USDC, lt: 9_400}));

            cts.push(CollateralTokenHuman({token: Tokens.WBTC, lt: 9_400}));

            cts.push(CollateralTokenHuman({token: Tokens.ARB, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.wstETH, lt: 9_600}));

            cts.push(CollateralTokenHuman({token: Tokens.rETH, lt: 9_600}));

            cts.push(CollateralTokenHuman({token: Tokens.cbETH, lt: 9_600}));

            cts.push(CollateralTokenHuman({token: Tokens.PENDLE, lt: 8_000}));

            cts.push(CollateralTokenHuman({token: Tokens.GMX, lt: 8_350}));

            cts.push(CollateralTokenHuman({token: Tokens.LINK, lt: 9_000}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
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
                        token1: Tokens.USDC,
                        fee: 500
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
                        token0: Tokens.WETH,
                        token1: Tokens.ARB,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.WETH,
                        token1: Tokens.ARB,
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
                        token0: Tokens.ARB,
                        token1: Tokens.USDC_e,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.ARB,
                        token1: Tokens.USDC,
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
                        token0: Tokens.PENDLE,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: Tokens.GMX,
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
            }
            cs.push(Contracts.BALANCER_VAULT);
            BalancerPool[] storage bp = cp.balancerPools;

            bp.push(
                BalancerPool({poolId: 0x9791d590788598535278552eecd4b211bfc790cb000000000000000000000498, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0xd0ec47c54ca5e20aaae4616c25c825c7f48d40690000000000000000000004ef, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0x2d6ced12420a9af5a83765a8c48be2afcd1a8feb000000000000000000000500, status: 2})
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
