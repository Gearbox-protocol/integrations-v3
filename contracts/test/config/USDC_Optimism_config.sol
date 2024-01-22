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

contract CONFIG_OPTIMISM_USDC_V3 is IPoolV3DeployConfig {
    string public constant id = "optimism-usdc-v3";
    uint256 public constant chainId = 10;
    Tokens public constant underlying = Tokens.USDC;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 10_000_000_000;

    // POOL

    string public constant symbol = "dUSDCV3";
    string public constant name = "Trade USDC v3";

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
        _gaugeRates.push(GaugeRate({token: Tokens.WBTC, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.WETH, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.OP, minRate: 4, maxRate: 12_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.WLD, minRate: 80, maxRate: 24_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.LINK, minRate: 80, maxRate: 24_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.SNX, minRate: 80, maxRate: 24_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvWETH, minRate: 4, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvOP, minRate: 4, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.wstETH, minRate: 4, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.rETH, minRate: 4, maxRate: 15_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvDAI, minRate: 5, maxRate: 8_50}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvUSDC, minRate: 5, maxRate: 7_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvUSDT, minRate: 5, maxRate: 9_00}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WBTC, quotaIncreaseFee: 1, limit: 3_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WETH, quotaIncreaseFee: 1, limit: 3_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.OP, quotaIncreaseFee: 1, limit: 3_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WLD, quotaIncreaseFee: 5, limit: 1_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LINK, quotaIncreaseFee: 5, limit: 1_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.SNX, quotaIncreaseFee: 5, limit: 1_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvWETH, quotaIncreaseFee: 1, limit: 400_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvOP, quotaIncreaseFee: 1, limit: 700_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.wstETH, quotaIncreaseFee: 1, limit: 700_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.rETH, quotaIncreaseFee: 1, limit: 1_500_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvDAI, quotaIncreaseFee: 0, limit: 400_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvUSDC, quotaIncreaseFee: 0, limit: 300_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvUSDT, quotaIncreaseFee: 0, limit: 300_000_000_000}));

        {
            /// CREDIT_MANAGER_0
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 1_000_000_000;
            cp.maxDebt = 200_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 50;
            cp.liquidationPremium = 100;
            cp.feeLiquidationExpired = 50;
            cp.liquidationPremiumExpired = 100;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 2_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 96_00}));

            cts.push(CollateralTokenHuman({token: Tokens.WBTC, lt: 96_00}));

            cts.push(CollateralTokenHuman({token: Tokens.OP, lt: 96_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvWETH, lt: 94_00}));

            cts.push(CollateralTokenHuman({token: Tokens.wstETH, lt: 94_00}));

            cts.push(CollateralTokenHuman({token: Tokens.rETH, lt: 94_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvOP, lt: 94_00}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.OP, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.USDC, fee: 500}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.USDC, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.WBTC, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.wstETH, token1: Tokens.WETH, fee: 100}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.WBTC, fee: 500}));
            uv3p.push(UniswapV3Pair({token0: Tokens.OP, token1: Tokens.USDC, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.OP, fee: 500}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.rETH, fee: 500}));
            cs.push(Contracts.BALANCER_VAULT);
            BalancerPool[] storage bp = cp.balancerPools;

            bp.push(
                BalancerPool({poolId: 0x4fd63966879300cafafbb35d157dc5229278ed2300020000000000000000002b, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb200020000000000000000008b, status: 2})
            );

            bp.push(
                BalancerPool({poolId: 0x39965c9dab5448482cf7e002f583c812ceb53046000100000000000000000003, status: 2})
            );
            cs.push(Contracts.YEARN_WETH_VAULT);
            cs.push(Contracts.YEARN_OP_VAULT);
        }
        {
            /// CREDIT_MANAGER_1
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 1_000_000_000;
            cp.maxDebt = 50_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 100;
            cp.liquidationPremium = 200;
            cp.feeLiquidationExpired = 100;
            cp.liquidationPremiumExpired = 200;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 1_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 95_00}));

            cts.push(CollateralTokenHuman({token: Tokens.WLD, lt: 92_00}));

            cts.push(CollateralTokenHuman({token: Tokens.LINK, lt: 92_00}));

            cts.push(CollateralTokenHuman({token: Tokens.SNX, lt: 92_00}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.USDC, fee: 500}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.USDC, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.WLD, fee: 10000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.LINK, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.SNX, fee: 3000}));
        }
        {
            /// CREDIT_MANAGER_2
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 10_000_000_000;
            cp.maxDebt = 300_000_000_000;
            cp.feeInterest = 2500;
            cp.feeLiquidation = 50;
            cp.liquidationPremium = 100;
            cp.feeLiquidationExpired = 50;
            cp.liquidationPremiumExpired = 100;
            cp.whitelisted = true;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 3_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.DAI, lt: 98_00}));

            cts.push(CollateralTokenHuman({token: Tokens.USDT, lt: 98_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvUSDC, lt: 96_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvDAI, lt: 96_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvUSDT, lt: 96_00}));

            cts.push(CollateralTokenHuman({token: Tokens._3Crv, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
            uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.USDT, fee: 100}));
            uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.USDC, fee: 100}));
            uv3p.push(UniswapV3Pair({token0: Tokens.USDT, token1: Tokens.DAI, fee: 100}));
            cs.push(Contracts.CURVE_3CRV_POOL);
            cs.push(Contracts.YEARN_DAI_VAULT);
            cs.push(Contracts.YEARN_USDC_VAULT);
            cs.push(Contracts.YEARN_USDT_VAULT);
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
