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

contract CONFIG_ARBITRUM_USDCE_V3 is IPoolV3DeployConfig {
    string public constant id = "arbitrum-usdce-v3";
    uint256 public constant chainId = 42161;
    Tokens public constant underlying = Tokens.USDC_e;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 10_000_000_000;

    // POOL

    string public constant symbol = "dUSDCV3";
    string public constant name = "Main USDC.e v3";

    PoolV3DeployParams _poolParams = PoolV3DeployParams({withdrawalFee: 0, totalDebtLimit: 100_000_000_000_000});

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
        _gaugeRates.push(GaugeRate({token: Tokens.WBTC, minRate: 4, maxRate: 1_200}));
        _gaugeRates.push(GaugeRate({token: Tokens.WETH, minRate: 4, maxRate: 1_200}));
        _gaugeRates.push(GaugeRate({token: Tokens.ARB, minRate: 80, maxRate: 2_400}));
        _gaugeRates.push(GaugeRate({token: Tokens.GMX, minRate: 80, maxRate: 2_400}));
        _gaugeRates.push(GaugeRate({token: Tokens.LINK, minRate: 80, maxRate: 2_400}));
        _gaugeRates.push(GaugeRate({token: Tokens.PENDLE, minRate: 80, maxRate: 2_400}));
        _gaugeRates.push(GaugeRate({token: Tokens.wstETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.rETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.cbETH, minRate: 4, maxRate: 1_500}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WBTC, quotaIncreaseFee: 1, limit: 4_500_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WETH, quotaIncreaseFee: 1, limit: 7_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.ARB, quotaIncreaseFee: 5, limit: 3_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.GMX, quotaIncreaseFee: 5, limit: 500_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LINK, quotaIncreaseFee: 5, limit: 500_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.PENDLE, quotaIncreaseFee: 5, limit: 500_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.wstETH, quotaIncreaseFee: 1, limit: 7_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.rETH, quotaIncreaseFee: 1, limit: 7_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.cbETH, quotaIncreaseFee: 1, limit: 7_000_000_000_000}));

        {
            /// CREDIT_MANAGER_0
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 1_000_000_000;
            cp.maxDebt = 400_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 50;
            cp.liquidationPremium = 100;
            cp.feeLiquidationExpired = 50;
            cp.liquidationPremiumExpired = 100;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 4_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 9_400}));

            cts.push(CollateralTokenHuman({token: Tokens.WBTC, lt: 9_400}));

            cts.push(CollateralTokenHuman({token: Tokens.ARB, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.wstETH, lt: 9_400}));

            cts.push(CollateralTokenHuman({token: Tokens.rETH, lt: 9_400}));

            cts.push(CollateralTokenHuman({token: Tokens.cbETH, lt: 9_400}));
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
                BalancerPool({poolId: 0x0c8972437a38b389ec83d1e666b69b8a4fcf8bfd00000000000000000000049e, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0x2d6ced12420a9af5a83765a8c48be2afcd1a8feb000000000000000000000500, status: 2})
            );
        }
        {
            /// CREDIT_MANAGER_1
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 1_000_000_000;
            cp.maxDebt = 100_000_000_000;
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
            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 9_400}));

            cts.push(CollateralTokenHuman({token: Tokens.GMX, lt: 8_350}));

            cts.push(CollateralTokenHuman({token: Tokens.LINK, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.PENDLE, lt: 8_000}));
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
