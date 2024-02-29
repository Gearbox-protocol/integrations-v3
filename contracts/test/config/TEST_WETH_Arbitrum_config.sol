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

contract CONFIG_ARBITRUM_WETH_TEST_V3 is IPoolV3DeployConfig {
    string public constant id = "arbitrum-weth-test-v3";
    uint256 public constant chainId = 42161;
    Tokens public constant underlying = Tokens.WETH;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 10_000_000_000_000_000_000;

    // POOL

    string public constant symbol = "dWETH-test-V3";
    string public constant name = "Test WETH v3";

    PoolV3DeployParams _poolParams =
        PoolV3DeployParams({withdrawalFee: 0, totalDebtLimit: 150_000_000_000_000_000_000_000});

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
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.USDC, quotaIncreaseFee: 1, limit: 2_000_000_000_000_000_000_000})
        );

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
            cts.push(CollateralTokenHuman({token: Tokens.USDC, lt: 94_00}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.CAMELOT_V3_ROUTER);
            {
                GenericSwapPair[] storage gsp = cp.genericSwapPairs;
                gsp.push(
                    GenericSwapPair({router: Contracts.CAMELOT_V3_ROUTER, token0: Tokens.WETH, token1: Tokens.USDC})
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
