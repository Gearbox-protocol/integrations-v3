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

contract CONFIG_MAINNET_USDC_TEST_V3 is IPoolV3DeployConfig {
    string public constant id = "mainnet-usdc-test-v3";
    uint256 public constant chainId = 1;
    uint256 public constant underlying = TOKEN_USDC;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 100_000_000_000;

    // POOL

    string public constant symbol = "dUSDC-test-V3";
    string public constant name = "Test USDC v3";

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
        _gaugeRates.push(GaugeRate({token: TOKEN_WETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_USDT, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_WBTC, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: TOKEN_USDe, minRate: 4, maxRate: 1_500}));
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_WETH, quotaIncreaseFee: 1, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_USDT, quotaIncreaseFee: 1, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_WBTC, quotaIncreaseFee: 1, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: TOKEN_USDe, quotaIncreaseFee: 1, limit: 10_000_000_000_000}));

        {
            /// CREDIT_MANAGER_0
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 50_000_000_000;
            cp.maxDebt = 1_000_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 150;
            cp.liquidationPremium = 400;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 5_000_000_000_000;
            cp.maxEnabledTokens = 4;
            cp.name = "Test Credit Manager";

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: TOKEN_WETH, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: TOKEN_USDT, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: TOKEN_WBTC, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: TOKEN_USDe, lt: 9_000}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            {
                UniswapV3Pair[] storage uv3p = cp.adapterConfig.uniswapV3Pairs;
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: TOKEN_USDC,
                        token1: TOKEN_WETH,
                        fee: 500
                    })
                );
                uv3p.push(
                    UniswapV3Pair({
                        router: Contracts.UNISWAP_V3_ROUTER,
                        token0: TOKEN_USDT,
                        token1: TOKEN_WETH,
                        fee: 3000
                    })
                );
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
                        token0: TOKEN_USDe,
                        token1: TOKEN_USDT,
                        fee: 100
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
