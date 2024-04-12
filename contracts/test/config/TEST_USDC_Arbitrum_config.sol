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

contract CONFIG_ARBITRUM_USDC_TEST_V3 is IPoolV3DeployConfig {
    string public constant id = "arbitrum-usdc-test-v3";
    uint256 public constant chainId = 42161;
    Tokens public constant underlying = Tokens.USDC_e;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 10_000_000_000;

    // POOL

    string public constant symbol = "dUSDC-test-V3";
    string public constant name = "Test USDC v3";

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
        _gaugeRates.push(GaugeRate({token: Tokens.USDT, minRate: 4, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.crvUSD, minRate: 4, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.cvxcrvUSDT, minRate: 10, maxRate: 10_00}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.USDT, quotaIncreaseFee: 1, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.crvUSD, quotaIncreaseFee: 1, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.cvxcrvUSDT, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));

        {
            /// CREDIT_MANAGER_0
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 1_000_000_000;
            cp.maxDebt = 100_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 50;
            cp.liquidationPremium = 100;
            cp.feeLiquidationExpired = 50;
            cp.liquidationPremiumExpired = 100;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 3_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.USDT, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSD, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.cvxcrvUSDT, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDT, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens._2CRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.CRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.CVX, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.ARB, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.USDC_e, fee: 500}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.ARB, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.ARB, token1: Tokens.USDC_e, fee: 500}));
            cs.push(Contracts.CURVE_2CRV_POOL_ARB);
            cs.push(Contracts.CURVE_CRVUSD_USDT_POOL_ARB);
            cs.push(Contracts.CONVEX_BOOSTER_ARB);
            cs.push(Contracts.CONVEX_CRVUSD_USDT_POOL_ARB);
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
