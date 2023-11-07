// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Foundation, 2023
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

contract CONFIG_MAINNET_USDC_MT_V3 is IPoolV3DeployConfig {
    string public constant id = "mainnet-usdc-mt-v3";
    uint256 public constant chainId = 1;
    Tokens public constant underlying = Tokens.USDC;
    bool public constant supportsQuotas = true;
    uint256 public constant getAccountAmount = 1_000_000_000_000;

    // POOL

    string public constant symbol = "dUSDCV3";
    string public constant name = "USDC v3 trade";

    PoolV3DeployParams _poolParams = PoolV3DeployParams({withdrawalFee: 0, expectedLiquidityLimit: 35_000_000_000_000});

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
        _gaugeRates.push(GaugeRate({token: Tokens.yvWETH, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.DAI, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.USDT, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.WBTC, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.FRAX, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.MKR, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.UNI, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.LINK, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.LDO, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.CRV, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.APE, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.CVX, minRate: 1, maxRate: 30_00}));
        _gaugeRates.push(GaugeRate({token: Tokens.FXS, minRate: 1, maxRate: 30_00}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WETH, quotaIncreaseFee: 0, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.yvWETH, quotaIncreaseFee: 1, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.DAI, quotaIncreaseFee: 0, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.USDT, quotaIncreaseFee: 0, limit: 30_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.WBTC, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.FRAX, quotaIncreaseFee: 0, limit: 10_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.MKR, quotaIncreaseFee: 2, limit: 2_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.UNI, quotaIncreaseFee: 2, limit: 2_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LINK, quotaIncreaseFee: 2, limit: 1_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.LDO, quotaIncreaseFee: 2, limit: 1_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.CRV, quotaIncreaseFee: 2, limit: 2_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.APE, quotaIncreaseFee: 2, limit: 300_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.CVX, quotaIncreaseFee: 2, limit: 1_000_000_000_000}));
        _quotaLimits.push(PoolQuotaLimit({token: Tokens.FXS, quotaIncreaseFee: 2, limit: 2_000_000_000_000}));

        {
            /// CREDIT_MANAGER_0
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 10_000_000_000;
            cp.maxDebt = 100_000_000_000;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 5_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.WBTC, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.USDT, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.DAI, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.FRAX, lt: 90_00}));

            cts.push(CollateralTokenHuman({token: Tokens.MKR, lt: 85_00}));

            cts.push(CollateralTokenHuman({token: Tokens.UNI, lt: 85_00}));

            cts.push(CollateralTokenHuman({token: Tokens.LINK, lt: 85_00}));

            cts.push(CollateralTokenHuman({token: Tokens.LDO, lt: 85_00}));

            cts.push(CollateralTokenHuman({token: Tokens.CRV, lt: 85_00}));

            cts.push(CollateralTokenHuman({token: Tokens.APE, lt: 85_00}));

            cts.push(CollateralTokenHuman({token: Tokens.CVX, lt: 85_00}));

            cts.push(CollateralTokenHuman({token: Tokens.FXS, lt: 85_00}));

            cts.push(CollateralTokenHuman({token: Tokens._3Crv, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvFRAX, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvCVXETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDTWBTCWETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.LDOETH, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSDETHCRV, lt: 0}));

            cts.push(CollateralTokenHuman({token: Tokens.crvUSD, lt: 0}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V2_ROUTER);
            {
                UniswapV2Pair[] storage uv2p = cp.uniswapV2Pairs;
                uv2p.push(
                    UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.WETH, token1: Tokens.USDT})
                );
                uv2p.push(
                    UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.USDC, token1: Tokens.WETH})
                );
                uv2p.push(
                    UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.USDC, token1: Tokens.USDT})
                );
                uv2p.push(UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.DAI, token1: Tokens.USDC}));
                uv2p.push(UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.DAI, token1: Tokens.WETH}));
                uv2p.push(UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.FXS, token1: Tokens.FRAX}));
                uv2p.push(
                    UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.WBTC, token1: Tokens.WETH})
                );
                uv2p.push(UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.DAI, token1: Tokens.MKR}));
                uv2p.push(UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.MKR, token1: Tokens.WETH}));
                uv2p.push(
                    UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.LINK, token1: Tokens.WETH})
                );
                uv2p.push(UniswapV2Pair({router: Contracts.UNISWAP_V2_ROUTER, token0: Tokens.SNX, token1: Tokens.WETH}));
            }
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
            uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.WETH, fee: 500}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WBTC, token1: Tokens.WETH, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.USDC, fee: 100}));
            uv3p.push(UniswapV3Pair({token0: Tokens.FRAX, token1: Tokens.USDC, fee: 500}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WBTC, token1: Tokens.WETH, fee: 500}));
            uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.WETH, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.USDT, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.USDC, fee: 500}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WBTC, token1: Tokens.USDC, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.USDT, fee: 500}));
            uv3p.push(UniswapV3Pair({token0: Tokens.UNI, token1: Tokens.WETH, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.USDT, fee: 100}));
            uv3p.push(UniswapV3Pair({token0: Tokens.MKR, token1: Tokens.WETH, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.LINK, token1: Tokens.WETH, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.FRAX, fee: 500}));
            uv3p.push(UniswapV3Pair({token0: Tokens.MKR, token1: Tokens.WETH, fee: 10000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.WETH, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.USDT, fee: 500}));
            uv3p.push(UniswapV3Pair({token0: Tokens.DAI, token1: Tokens.WETH, fee: 500}));
            uv3p.push(UniswapV3Pair({token0: Tokens.LDO, token1: Tokens.WETH, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WBTC, token1: Tokens.USDT, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.WETH, token1: Tokens.RPL, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.WETH, fee: 10000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.APE, token1: Tokens.WETH, fee: 3000}));
            uv3p.push(UniswapV3Pair({token0: Tokens.CRV, token1: Tokens.WETH, fee: 3000}));
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
                uv2p.push(UniswapV2Pair({router: Contracts.SUSHISWAP_ROUTER, token0: Tokens.LINK, token1: Tokens.WETH}));
            }
            cs.push(Contracts.FRAXSWAP_ROUTER);
            {
                UniswapV2Pair[] storage uv2p = cp.uniswapV2Pairs;
                uv2p.push(UniswapV2Pair({router: Contracts.FRAXSWAP_ROUTER, token0: Tokens.FRAX, token1: Tokens.FXS}));
                uv2p.push(UniswapV2Pair({router: Contracts.FRAXSWAP_ROUTER, token0: Tokens.FRAX, token1: Tokens.WETH}));
            }
            cs.push(Contracts.CURVE_3CRV_POOL);
            cs.push(Contracts.CURVE_FRAX_USDC_POOL);
            cs.push(Contracts.CURVE_CVXETH_POOL);
            cs.push(Contracts.CURVE_3CRYPTO_POOL);
            cs.push(Contracts.CURVE_LDOETH_POOL);
            cs.push(Contracts.CURVE_TRI_CRV_POOL);
        }
        {
            /// CREDIT_MANAGER_1
            CreditManagerV3DeployParams storage cp = _creditManagers.push();

            cp.minDebt = 10_000_000_000;
            cp.maxDebt = 2_000_000_000_000;
            cp.whitelisted = false;
            cp.expirable = false;
            cp.skipInit = false;
            cp.poolLimit = 30_000_000_000_000;

            CollateralTokenHuman[] storage cts = cp.collateralTokens;
            cts.push(CollateralTokenHuman({token: Tokens.WETH, lt: 87_00}));

            cts.push(CollateralTokenHuman({token: Tokens.yvWETH, lt: 85_00}));
            Contracts[] storage cs = cp.contracts;
            cs.push(Contracts.UNISWAP_V3_ROUTER);
            UniswapV3Pair[] storage uv3p = cp.uniswapV3Pairs;
            uv3p.push(UniswapV3Pair({token0: Tokens.USDC, token1: Tokens.WETH, fee: 500}));
            cs.push(Contracts.YEARN_WETH_VAULT);
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
