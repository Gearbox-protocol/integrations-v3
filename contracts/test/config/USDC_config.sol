// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk/contracts/SupportedContracts.sol";
import {
    LinearIRMV3DeployParams,
    PoolV3DeployParams,
    CreditManagerV3DeployParams,
    GaugeRate,
    PoolQuotaLimit,
    CollateralToken,
    IPoolV3DeployConfig,
    CollateralTokenHuman
} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";

contract PoolV3DeployConfig_dUSDC is IPoolV3DeployConfig {
    string public constant symbol = "dUSDC";
    string public constant name = "Diesel USDC V3 pool";
    uint256 public constant chainId = 1;

    Tokens public constant underlying = Tokens.USDC;
    bool public constant supportsQuotas = true;

    uint256 public constant getAccountAmount = 1_000_000 * 1e6;

    PoolV3DeployParams _poolParams = PoolV3DeployParams({withdrawalFee: 0, expectedLiquidityLimit: 0});

    LinearIRMV3DeployParams _irm = LinearIRMV3DeployParams({
        U_1: 80_00,
        U_2: 90_00,
        R_base: 0,
        R_slope1: 5,
        R_slope2: 20,
        R_slope3: 100_00,
        _isBorrowingMoreU2Forbidden: true
    });

    GaugeRate[] _gaugeRates;
    PoolQuotaLimit[] _quotaLimits;

    CreditManagerV3DeployParams[] _creditManagers;

    constructor() {
        _gaugeRates.push(GaugeRate({token: Tokens.LINK, minRate: 10, maxRate: 20}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LINK, quotaIncreaseFee: 10_00, limit: 500_000}));

        /// CREDIT_MANAGER_0
        CreditManagerV3DeployParams storage cp = _creditManagers.push();

        cp.minDebt = 1_000_000 * 1e6;
        cp.maxDebt = 10_000_000 * 1e6;
        cp.whitelisted = false;
        cp.expirable = false;
        cp.skipInit = false;
        cp.poolLimit = 5_000_000 * 1e6;

        CollateralTokenHuman[] storage cts = cp.collateralTokens;
        cts.push(CollateralTokenHuman({token: Tokens.USDC, lt: 90_00}));
        cts.push(CollateralTokenHuman({token: Tokens.LINK, lt: 80_00}));
        cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 70_00}));

        Contracts[] storage cs = cp.contracts;
        cs.push(Contracts.SUSHISWAP_ROUTER);
        cs.push(Contracts.CURVE_3CRV_POOL);

        /// CREDIT_MANAGER_1
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
