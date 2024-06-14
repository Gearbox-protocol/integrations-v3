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

contract CONFIG_MAINNET_USDC_TEST_V3 is IPoolV3DeployConfig {
    string public constant id = "mainnet-usdc-test-v3";
    uint256 public constant chainId = 1;
    Tokens public constant underlying = Tokens.USDC;
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
        _gaugeRates.push(GaugeRate({token: Tokens.USDe, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.WETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.pufETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.zpufETH, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.LDO, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.USDeUSDC, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.GHO, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.crvUSD, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.GHOcrvUSD, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.cvxGHOcrvUSD, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvxGHOcrvUSD, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.CRV, minRate: 4, maxRate: 1_500}));
        _gaugeRates.push(GaugeRate({token: Tokens.CVX, minRate: 4, maxRate: 1_500}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.USDe, quotaIncreaseFee: 1, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WETH, quotaIncreaseFee: 1, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.pufETH, quotaIncreaseFee: 1, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.zpufETH, quotaIncreaseFee: 1, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LDO, quotaIncreaseFee: 1, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.USDeUSDC, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.GHO, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.crvUSD, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.GHOcrvUSD, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.cvxGHOcrvUSD, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.stkcvxGHOcrvUSD, quotaIncreaseFee: 0, limit: 10_000_000_000_000})
        );
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.CRV, quotaIncreaseFee: 0, limit: 0}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.CVX, quotaIncreaseFee: 0, limit: 0}));

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

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.USDe, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.pufETH, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.zpufETH, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.LDO, lt: 8_250}));

            cts.push(CollateralTokenHuman({token: Tokens.GHO, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSD, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.stkcvxGHOcrvUSD, lt: 9_000}));

            cts.push(CollateralTokenHuman({token: Tokens.USDeUSDC, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.GHOcrvUSD, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.cvxGHOcrvUSD, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.CRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.CVX, lt: 0}));
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
                        token0: Tokens.LDO,
                        token1: Tokens.WETH,
                        fee: 3000
                    })
                );
            }
            cs.push(Contracts.CURVE_USDE_USDC_POOL);
            cs.push(Contracts.CURVE_GHO_CRVUSD_POOL);
            cs.push(Contracts.ZIRCUIT_POOL);
            cs.push(Contracts.CONVEX_BOOSTER);
            cs.push(Contracts.CONVEX_GHO_CRVUSD_POOL);
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
