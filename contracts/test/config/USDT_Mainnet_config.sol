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

contract CONFIG_MAINNET_USDT_V3 is IPoolV3DeployConfig {
    string public constant id = "mainnet-usdt-v3";
    uint256 public constant chainId = 1;
    Tokens public constant underlying = Tokens.USDT;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 100_000_000_000;

    // POOL

    string public constant symbol = "dUSDTV3";
    string public constant name = "Universal USDT v3";

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
        _gaugeRates.push(GaugeRate({token: Tokens.USDC, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.sDAI, minRate: 5, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.USDe, minRate: 5, maxRate: 50_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.sUSDe, minRate: 5, maxRate: 50_00}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.DAI, quotaIncreaseFee: 1, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.USDC, quotaIncreaseFee: 1, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.sDAI, quotaIncreaseFee: 0, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.USDe, quotaIncreaseFee: 0, limit: 5_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.sUSDe, quotaIncreaseFee: 0, limit: 0}));

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
            cp.poolLimit = 10_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.USDC, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.DAI, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.USDe, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.sUSDe, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.sDAI, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens._3Crv, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.USDeDAI, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.USDeUSDC, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.MtEthena, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.CURVE_3CRV_POOL);
            cs.push(Contracts.CURVE_USDE_DAI_POOL);
            cs.push(Contracts.CURVE_USDE_USDC_POOL);
            cs.push(Contracts.CURVE_SDAI_SUSDE_POOL);
            cs.push(Contracts.MAKER_DSR_VAULT);
            cs.push(Contracts.STAKED_USDE_VAULT);
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
