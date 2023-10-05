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

contract CONFIG_MAINNET_USDC_LEV_V3 is IPoolV3DeployConfig {
    string public constant id = "mainnet-usdc-lev-v3";
    uint256 public constant chainId = 1;
    Tokens public constant underlying = Tokens.USDC;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 1_000_000_000_000;

    // POOL

    string public constant symbol = "dUSDC-lev-V3";
    string public constant name = "Diesel USDC V3 leverage pool";

    PoolV3DeployParams _poolParams = PoolV3DeployParams({withdrawalFee: 0, expectedLiquidityLimit: 10_000_000_000_000});

    LinearIRMV3DeployParams _irm = LinearIRMV3DeployParams({
        U_1: 70_00,
        U_2: 90_00,
        R_base: 0,
        R_slope1: 1_50,
        R_slope2: 4_00,
        R_slope3: 100_00,
        _isBorrowingMoreU2Forbidden: true
    });

    GaugeRate[] _gaugeRates;
    PoolQuotaLimit[] _quotaLimits;

    CreditManagerV3DeployParams[] _creditManagers;

    constructor() {
        _gaugeRates.push(GaugeRate({token: Tokens.WETH, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.STETH, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.wstETH, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.WBTC, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.LINK, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.aDAI, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.cLINK, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.sDAI, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.YieldETH, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.DAI, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.USDT, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.sUSD, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.FRAX, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.GUSD, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.LUSD, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.steCRV, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.cvxsteCRV, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvxsteCRV, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens._3Crv, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.cvx3Crv, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvx3Crv, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.FRAX3CRV, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.cvxFRAX3CRV, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvxFRAX3CRV, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.LUSD3CRV, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.cvxLUSD3CRV, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvxLUSD3CRV, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.crvPlain3andSUSD, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.cvxcrvPlain3andSUSD, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvxcrvPlain3andSUSD, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.gusd3CRV, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.cvxgusd3CRV, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvxgusd3CRV, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.crvFRAX, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.cvxcrvFRAX, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.stkcvxcrvFRAX, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvDAI, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvUSDC, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvWETH, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvWBTC, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvCurve_stETH, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.yvCurve_FRAX, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.CVX, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.FXS, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.LQTY, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.CRV, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.LDO, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.SNX, minRate: 1, maxRate: 30_00}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WETH, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.STETH, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.wstETH, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WBTC, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LINK, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.aDAI, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.cLINK, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.sDAI, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.YieldETH, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.DAI, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.USDT, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.sUSD, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.FRAX, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.GUSD, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LUSD, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.steCRV, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.cvxsteCRV, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.stkcvxsteCRV, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens._3Crv, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.cvx3Crv, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.stkcvx3Crv, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.FRAX3CRV, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.cvxFRAX3CRV, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.stkcvxFRAX3CRV, quotaIncreaseFee: 0, limit: 10_000_000_000_000})
        );
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LUSD3CRV, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.cvxLUSD3CRV, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.stkcvxLUSD3CRV, quotaIncreaseFee: 0, limit: 10_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.crvPlain3andSUSD, quotaIncreaseFee: 0, limit: 10_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.cvxcrvPlain3andSUSD, quotaIncreaseFee: 0, limit: 10_000_000_000_000})
        );
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.stkcvxcrvPlain3andSUSD, quotaIncreaseFee: 0, limit: 10_000_000_000_000})
        );
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.gusd3CRV, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.cvxgusd3CRV, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(
            PoolQuotaLimit({token: Tokens.stkcvxgusd3CRV, quotaIncreaseFee: 0, limit: 10_000_000_000_000})
        );
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.crvFRAX, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.cvxcrvFRAX, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.stkcvxcrvFRAX, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvDAI, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvUSDC, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvWETH, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvWBTC, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvCurve_stETH, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvCurve_FRAX, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.CVX, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.FXS, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LQTY, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.CRV, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LDO, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.SNX, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));

        /// CREDIT_MANAGER_0
        CreditManagerV3DeployParams storage cp = _creditManagers.push();

        cp.minDebt = 10_000_000_000;
        cp.maxDebt = 1_000_000_000_000;
        cp.whitelisted = false;
        cp.expirable = false;
        cp.skipInit = false;
        cp.poolLimit = 10_000_000_000_000;

        CollateralTokenHuman[] storage cts = cp.collateralTokens;
        cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 85_00}));

        cts.push(CollateralTokenHuman({token: Tokens.STETH, lt: 82_50}));

        cts.push(CollateralTokenHuman({token: Tokens.wstETH, lt: 82_50}));

        cts.push(CollateralTokenHuman({token: Tokens.WBTC, lt: 85_00}));

        cts.push(CollateralTokenHuman({token: Tokens.LINK, lt: 80_00}));

        cts.push(CollateralTokenHuman({token: Tokens.aDAI, lt: 92_00}));

        cts.push(CollateralTokenHuman({token: Tokens.cLINK, lt: 85_00}));

        cts.push(CollateralTokenHuman({token: Tokens.sDAI, lt: 92_00}));

        cts.push(CollateralTokenHuman({token: Tokens.DAI, lt: 92_00}));

        cts.push(CollateralTokenHuman({token: Tokens.USDT, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.sUSD, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.FRAX, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.GUSD, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.LUSD, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.steCRV, lt: 82_50}));

        cts.push(CollateralTokenHuman({token: Tokens.cvxsteCRV, lt: 82_50}));

        cts.push(CollateralTokenHuman({token: Tokens.stkcvxsteCRV, lt: 82_50}));

        cts.push(CollateralTokenHuman({token: Tokens._3Crv, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.cvx3Crv, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.stkcvx3Crv, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.FRAX3CRV, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.cvxFRAX3CRV, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.stkcvxFRAX3CRV, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.LUSD3CRV, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.cvxLUSD3CRV, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.stkcvxLUSD3CRV, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.crvPlain3andSUSD, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.cvxcrvPlain3andSUSD, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.stkcvxcrvPlain3andSUSD, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.gusd3CRV, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.cvxgusd3CRV, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.stkcvxgusd3CRV, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.crvFRAX, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.cvxcrvFRAX, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.stkcvxcrvFRAX, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.yvDAI, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.yvUSDC, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.yvWETH, lt: 82_50}));

        cts.push(CollateralTokenHuman({token: Tokens.yvWBTC, lt: 82_50}));

        cts.push(CollateralTokenHuman({token: Tokens.yvCurve_stETH, lt: 82_50}));

        cts.push(CollateralTokenHuman({token: Tokens.yvCurve_FRAX, lt: 90_00}));

        cts.push(CollateralTokenHuman({token: Tokens.CVX, lt: 0}));

        cts.push(CollateralTokenHuman({token: Tokens.FXS, lt: 0}));

        cts.push(CollateralTokenHuman({token: Tokens.LQTY, lt: 0}));

        cts.push(CollateralTokenHuman({token: Tokens.CRV, lt: 25_00}));

        cts.push(CollateralTokenHuman({token: Tokens.LDO, lt: 0}));

        cts.push(CollateralTokenHuman({token: Tokens.SNX, lt: 25}));
        Contracts[] storage cs = cp.contracts;
        cs.push(Contracts.UNISWAP_V3_ROUTER);
        UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
        uv3p.push(UniswapV3Pair({token0: Tokens.SNX, token1: Tokens.WETH, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WBTC, token1: Tokens.WETH, fee: 500}));
        uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.WETH, fee: 500}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WBTC, token1: Tokens.WETH, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.WETH, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.WETH, fee: 500}));
        uv3p.push(UniswapV3Pair({token0: Tokens.LDO, token1: Tokens.WETH, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.WETH, fee: 10000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.LDO, token1: Tokens.WETH, fee: 10000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.LQTY, token1: Tokens.WETH, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.FXS, token1: Tokens.WETH, fee: 10000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.WETH, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.WETH, fee: 10000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.USDT, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.FRAX, token1: Tokens.USDT, fee: 500}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.USDT, fee: 500}));
        uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.USDT, fee: 500}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WBTC, token1: Tokens.USDT, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.USDT, fee: 10000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.USDT, fee: 100}));
        uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.USDT, fee: 10000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.USDT, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.FXS, token1: Tokens.USDT, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.USDT, fee: 100}));
        uv3p.push(UniswapV3Pair({token0: Tokens.LUSD, token1: Tokens.USDC, fee: 500}));
        uv3p.push(UniswapV3Pair({token0: Tokens.FRAX, token1: Tokens.USDC, fee: 100}));
        uv3p.push(UniswapV3Pair({token0: Tokens.LUSD, token1: Tokens.USDC, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.FRAX, token1: Tokens.USDC, fee: 500}));
        uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.USDC, fee: 500}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WBTC, token1: Tokens.USDC, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.LDO, token1: Tokens.USDC, fee: 10000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WBTC, token1: Tokens.USDC, fee: 10000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WBTC, token1: Tokens.USDC, fee: 500}));
        uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.USDC, fee: 100}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WBTC, token1: Tokens.LQTY, fee: 10000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.sUSD, token1: Tokens.FRAX, fee: 500}));
        uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.FRAX, fee: 500}));
        uv3p.push(UniswapV3Pair({token0: Tokens.FXS, token1: Tokens.FRAX, fee: 10000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WBTC, token1: Tokens.DAI, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.FXS, token1: Tokens.CVX, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.CVX, token1: Tokens.CRV, fee: 10000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.CRV, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.CRV, fee: 10000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.CVX, fee: 10000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.SNX, token1: Tokens.USDC, fee: 10000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.OHM, token1: Tokens.USDC, fee: 3000}));
        uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.LINK, fee: 3000}));
        cs.push(Contracts.UNISWAP_V2_ROUTER);
        {
            UniswapV2Pair[] storage uv2p = cp.uniswapV2Pairs;
            uv2p.push(UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.WETH, token1: Tokens.USDT}));
            uv2p.push(UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.USDC, token1: Tokens.WETH}));
            uv2p.push(UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.USDC, token1: Tokens.USDT}));
            uv2p.push(UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.DAI, token1: Tokens.USDC}));
            uv2p.push(UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.DAI, token1: Tokens.WETH}));
            uv2p.push(UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.FXS, token1: Tokens.FRAX}));
            uv2p.push(UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.WBTC, token1: Tokens.WETH}));
        }
        cs.push(Contracts.SUSHISWAP_ROUTER);
        {
            UniswapV2Pair[] storage uv2p = cp.uniswapV2Pairs;
            uv2p.push(UniswapV2Pair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.WBTC, token1: Tokens.WETH}));
            uv2p.push(UniswapV2Pair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.WETH, token1: Tokens.USDT}));
            uv2p.push(UniswapV2Pair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.USDC, token1: Tokens.WETH}));
            uv2p.push(UniswapV2Pair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.DAI, token1: Tokens.WETH}));
            uv2p.push(UniswapV2Pair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.WETH, token1: Tokens.FXS}));
            uv2p.push(UniswapV2Pair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.LDO, token1: Tokens.WETH}));
            uv2p.push(UniswapV2Pair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.CVX, token1: Tokens.WETH}));
            uv2p.push(UniswapV2Pair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.CRV, token1: Tokens.WETH}));
            uv2p.push(UniswapV2Pair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.SNX, token1: Tokens.WETH}));
        }
        cs.push(Contracts.BALANCER_VAULT);
        BalancerPool[] storage bp = cp.balancerPools;

        bp.push(BalancerPool({poolId: 0x76fcf0e8c7ff37a47a799fa2cd4c13cde0d981c90002000000000000000003d2, status: 2}));
        cs.push(Contracts.CURVE_3CRV_POOL);
        cs.push(Contracts.CURVE_FRAX_USDC_POOL);
        cs.push(Contracts.CURVE_STETH_GATEWAY);
        cs.push(Contracts.CURVE_FRAX_POOL);
        cs.push(Contracts.CURVE_SUSD_POOL);
        cs.push(Contracts.CURVE_LUSD_POOL);
        cs.push(Contracts.CURVE_GUSD_POOL);
        cs.push(Contracts.CURVE_SUSD_DEPOSIT);
        cs.push(Contracts.YEARN_DAI_VAULT);
        cs.push(Contracts.YEARN_USDC_VAULT);
        cs.push(Contracts.YEARN_WETH_VAULT);
        cs.push(Contracts.YEARN_WBTC_VAULT);
        cs.push(Contracts.YEARN_CURVE_FRAX_VAULT);
        cs.push(Contracts.YEARN_CURVE_STETH_VAULT);
        cs.push(Contracts.CONVEX_FRAX3CRV_POOL);
        cs.push(Contracts.CONVEX_LUSD3CRV_POOL);
        cs.push(Contracts.CONVEX_GUSD_POOL);
        cs.push(Contracts.CONVEX_SUSD_POOL);
        cs.push(Contracts.CONVEX_3CRV_POOL);
        cs.push(Contracts.CONVEX_FRAX_USDC_POOL);
        cs.push(Contracts.CONVEX_STECRV_POOL);
        cs.push(Contracts.CONVEX_BOOSTER);
        cs.push(Contracts.LIDO_WSTETH);
        cs.push(Contracts.AAVE_V2_LENDING_POOL);
        cs.push(Contracts.COMPOUND_V2_LINK_POOL);
        cs.push(Contracts.MAKER_DSR_VAULT);
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
