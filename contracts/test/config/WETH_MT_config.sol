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
    CollateralToken,
    IPoolV3DeployConfig,
    CollateralTokenHuman,
    UniswapV2Pair,
    UniswapV3Pair,
    BalancerPool
} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";

contract CONFIG_MAINNET_WETH_MT_V3 is IPoolV3DeployConfig {
    string public constant id = "mainnet-weth-mt-v3";
    uint256 public constant chainId = 1;
    Tokens public constant underlying = Tokens.WETH;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 1_000_000_000_000_000_000_000_000;

    // POOL

    string public constant symbol = "dWETHV3";
    string public constant name = "WETH v3";

    PoolV3DeployParams _poolParams =
        PoolV3DeployParams({withdrawalFee: 0, expectedLiquidityLimit: 16_666_000_000_000_000_000_000});

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
        _gaugeRates.push(GaugeRate({token: Tokens.USDC, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.DAI, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvUSDC, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.sDAI, minRate: 1, maxRate: 30_00}));
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.USDC, quotaIncreaseFee: 1, limit: 16_666_666_666_666_666_666_666})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.DAI, quotaIncreaseFee: 1, limit: 16_666_666_666_666_666_666_666})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.yvUSDC, quotaIncreaseFee: 1, limit: 5_555_555_555_555_555_555_555})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.sDAI, quotaIncreaseFee: 1, limit: 5_555_000_000_000_000_000_000})
        );

        {
            /// CREDIT_MANAGER_0
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 5_555_555_555_555_555_555;
            cp.maxDebt = 1_111_111_111_111_111_111_111;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 16_666_000_000_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.USDC, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.DAI, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvUSDC, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.sDAI, lt: 87_00}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
            uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.WETH, fee: 500}));
            uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.USDC, fee: 100}));
            uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.WETH, fee: 3000}));
            cs.push(Contracts.YEARN_USDC_VAULT);
            cs.push(Contracts.MAKER_DSR_VAULT);
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
