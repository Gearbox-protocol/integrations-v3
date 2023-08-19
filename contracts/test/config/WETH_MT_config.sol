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

contract CONFIG_MAINNET_WETH_MT_V3 is IPoolV3DeployConfig {
    string public constant id = "mainnet-weth-mt-v3";
    uint256 public constant chainId = 1;
    Tokens public constant underlying = Tokens.WETH;
    bool public constant supportsQuotas = false;
    uint256 public constant getAccountAmount = 1_000_000_000_000_000_000_000_000;

    // POOL

    string public constant symbol = "dWETHV3";
    string public constant name = "Diesel WETH V3 pool";

    PoolV3DeployParams _poolParams = PoolV3DeployParams({withdrawalFee: 0, expectedLiquidityLimit: 0});

    LinearIRMV3DeployParams _irm = LinearIRMV3DeployParams({
        U_1: 70_00,
        U_2: 90_00,
        R_base: 0,
        R_slope1: 1_00,
        R_slope2: 2_00,
        R_slope3: 100_00,
        _isBorrowingMoreU2Forbidden: true
    });

    GaugeRate[] _gaugeRates;
    PoolQuotaLimit[] _quotaLimits;

    CreditManagerV3DeployParams[] _creditManagers;

    constructor() {
        _gaugeRates.push(GaugeRate({token: Tokens.STETH, minRate: 0, maxRate: 2_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.USDC, minRate: 0, maxRate: 30_00}));
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.STETH, quotaIncreaseFee: 0, limit: 16_666_666_666_666_666_666_666})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.USDC, quotaIncreaseFee: 0, limit: 16_666_666_666_666_666_666_666})
        );

        /// CREDIT_MANAGER_0
        CreditManagerV3DeployParams storage cp = _creditManagers.push();

        cp.minDebt = 5_555_555_555_555_555_555;
        cp.maxDebt = 555_555_555_555_555_555_555;
        cp.whitelisted = false;
        cp.expirable = false;
        cp.skipInit = false;
        cp.poolLimit = 0;

        CollateralTokenHuman[] storage cts = cp.collateralTokens;
        cts.push(CollateralTokenHuman({token: Tokens.WBTC, lt: 87_00}));

        cts.push(CollateralTokenHuman({token: Tokens.USDC, lt: 87_00}));
        Contracts[] storage cs = cp.contracts;
        cs.push(Contracts.UNISWAP_V3_ROUTER);
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
