// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {Tokens} from "./Tokens.sol";
import {Contracts} from "./SupportedContracts.sol";
import {AdapterType} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

struct SimpleAdapter {
    Contracts targetContract;
    AdapterType adapterType;
}

struct CurveAdapter {
    Contracts targetContract;
    AdapterType adapterType;
    Tokens lpToken;
    Contracts basePool;
}

struct CurveStETHAdapter {
    Contracts curveETHGateway;
    AdapterType adapterType;
    Tokens lpToken;
}

struct CurveWrapper {
    Contracts targetContract;
    AdapterType adapterType;
    Tokens lpToken;
    uint256 nCoins;
}

struct ConvexBasePoolAdapter {
    Contracts targetContract;
    AdapterType adapterType;
    Tokens stakedToken;
}

contract AdapterData {
    SimpleAdapter[] simpleAdapters;
    CurveAdapter[] curveAdapters;
    CurveStETHAdapter curveStEthAdapter;
    CurveWrapper[] curveWrappers;
    ConvexBasePoolAdapter[] convexBasePoolAdapters;

    constructor() {
        simpleAdapters.push(
            SimpleAdapter({targetContract: Contracts.UNISWAP_V2_ROUTER, adapterType: AdapterType.UNISWAP_V2_ROUTER})
        );
        simpleAdapters.push(
            SimpleAdapter({targetContract: Contracts.UNISWAP_V3_ROUTER, adapterType: AdapterType.UNISWAP_V3_ROUTER})
        );
        simpleAdapters.push(
            SimpleAdapter({targetContract: Contracts.SUSHISWAP_ROUTER, adapterType: AdapterType.UNISWAP_V2_ROUTER})
        );
        simpleAdapters.push(
            SimpleAdapter({targetContract: Contracts.YEARN_DAI_VAULT, adapterType: AdapterType.YEARN_V2})
        );
        simpleAdapters.push(
            SimpleAdapter({targetContract: Contracts.YEARN_USDC_VAULT, adapterType: AdapterType.YEARN_V2})
        );
        simpleAdapters.push(
            SimpleAdapter({targetContract: Contracts.YEARN_WETH_VAULT, adapterType: AdapterType.YEARN_V2})
        );
        simpleAdapters.push(
            SimpleAdapter({targetContract: Contracts.YEARN_WBTC_VAULT, adapterType: AdapterType.YEARN_V2})
        );
        simpleAdapters.push(
            SimpleAdapter({targetContract: Contracts.YEARN_CURVE_FRAX_VAULT, adapterType: AdapterType.YEARN_V2})
        );
        simpleAdapters.push(
            SimpleAdapter({targetContract: Contracts.YEARN_CURVE_STETH_VAULT, adapterType: AdapterType.YEARN_V2})
        );
        simpleAdapters.push(
            SimpleAdapter({targetContract: Contracts.CONVEX_BOOSTER, adapterType: AdapterType.CONVEX_V1_BOOSTER})
        );
        simpleAdapters.push(
            SimpleAdapter({targetContract: Contracts.AURA_BOOSTER, adapterType: AdapterType.CONVEX_V1_BOOSTER})
        );
        simpleAdapters.push(
            SimpleAdapter({targetContract: Contracts.LIDO_STETH_GATEWAY, adapterType: AdapterType.LIDO_V1})
        );
        simpleAdapters.push(
            SimpleAdapter({targetContract: Contracts.LIDO_WSTETH, adapterType: AdapterType.LIDO_WSTETH_V1})
        );
        simpleAdapters.push(
            SimpleAdapter({targetContract: Contracts.BALANCER_VAULT, adapterType: AdapterType.BALANCER_VAULT})
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_3CRV_POOL,
                adapterType: AdapterType.CURVE_V1_3ASSETS,
                lpToken: Tokens._3Crv,
                basePool: Contracts.NO_CONTRACT
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_FRAX_USDC_POOL,
                adapterType: AdapterType.CURVE_V1_2ASSETS,
                lpToken: Tokens.crvFRAX,
                basePool: Contracts.NO_CONTRACT
            })
        );

        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_FRAX_POOL,
                adapterType: AdapterType.CURVE_V1_2ASSETS,
                lpToken: Tokens.FRAX3CRV,
                basePool: Contracts.CURVE_3CRV_POOL
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_LUSD_POOL,
                adapterType: AdapterType.CURVE_V1_2ASSETS,
                lpToken: Tokens.LUSD3CRV,
                basePool: Contracts.CURVE_3CRV_POOL
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_SUSD_POOL,
                adapterType: AdapterType.CURVE_V1_4ASSETS,
                lpToken: Tokens.crvPlain3andSUSD,
                basePool: Contracts.NO_CONTRACT
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_GUSD_POOL,
                adapterType: AdapterType.CURVE_V1_2ASSETS,
                lpToken: Tokens.gusd3CRV,
                basePool: Contracts.CURVE_3CRV_POOL
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_MIM_POOL,
                adapterType: AdapterType.CURVE_V1_2ASSETS,
                lpToken: Tokens.MIM_3LP3CRV,
                basePool: Contracts.CURVE_3CRV_POOL
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_OHMFRAXBP_POOL,
                adapterType: AdapterType.CURVE_V1_2ASSETS,
                lpToken: Tokens.OHMFRAXBP,
                basePool: Contracts.CURVE_FRAX_USDC_POOL
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_CRVETH_POOL,
                adapterType: AdapterType.CURVE_V1_2ASSETS,
                lpToken: Tokens.crvCRVETH,
                basePool: Contracts.NO_CONTRACT
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_CVXETH_POOL,
                adapterType: AdapterType.CURVE_V1_2ASSETS,
                lpToken: Tokens.crvCVXETH,
                basePool: Contracts.NO_CONTRACT
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_3CRYPTO_POOL,
                adapterType: AdapterType.CURVE_V1_3ASSETS,
                lpToken: Tokens.crvUSDTWBTCWETH,
                basePool: Contracts.NO_CONTRACT
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_LDOETH_POOL,
                adapterType: AdapterType.CURVE_V1_2ASSETS,
                lpToken: Tokens.LDOETH,
                basePool: Contracts.NO_CONTRACT
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_CRVUSD_USDC_POOL,
                adapterType: AdapterType.CURVE_V1_2ASSETS,
                lpToken: Tokens.crvUSDUSDC,
                basePool: Contracts.NO_CONTRACT
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_CRVUSD_USDT_POOL,
                adapterType: AdapterType.CURVE_V1_2ASSETS,
                lpToken: Tokens.crvUSDUSDT,
                basePool: Contracts.NO_CONTRACT
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_CRVUSD_FRAX_POOL,
                adapterType: AdapterType.CURVE_V1_2ASSETS,
                lpToken: Tokens.crvUSDFRAX,
                basePool: Contracts.NO_CONTRACT
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_TRI_CRV_POOL,
                adapterType: AdapterType.CURVE_V1_3ASSETS,
                lpToken: Tokens.crvUSDETHCRV,
                basePool: Contracts.NO_CONTRACT
            })
        );
        curveAdapters.push(
            CurveAdapter({
                targetContract: Contracts.CURVE_RETH_ETH_POOL,
                adapterType: AdapterType.CURVE_V1_2ASSETS,
                lpToken: Tokens.rETH_f,
                basePool: Contracts.NO_CONTRACT
            })
        );
        curveStEthAdapter = CurveStETHAdapter({
            curveETHGateway: Contracts.CURVE_STETH_GATEWAY,
            adapterType: AdapterType.CURVE_V1_STECRV_POOL,
            lpToken: Tokens.steCRV
        });
        curveWrappers.push(
            CurveWrapper({
                targetContract: Contracts.CURVE_SUSD_DEPOSIT,
                adapterType: AdapterType.CURVE_V1_WRAPPER,
                lpToken: Tokens.crvPlain3andSUSD,
                nCoins: 4
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.CONVEX_3CRV_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.stkcvx3Crv
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.CONVEX_FRAX_USDC_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.stkcvxcrvFRAX
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.CONVEX_GUSD_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.stkcvxgusd3CRV
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.CONVEX_SUSD_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.stkcvxcrvPlain3andSUSD
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.CONVEX_STECRV_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.stkcvxsteCRV
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.CONVEX_FRAX3CRV_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.stkcvxFRAX3CRV
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.CONVEX_LUSD3CRV_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.stkcvxLUSD3CRV
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.CONVEX_MIM3CRV_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.stkcvxMIM_3LP3CRV
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.CONVEX_OHMFRAXBP_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.stkcvxOHMFRAXBP
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.CONVEX_CRVETH_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.stkcvxcrvCRVETH
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.CONVEX_CVXETH_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.stkcvxcrvCVXETH
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.CONVEX_3CRYPTO_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.stkcvxcrvUSDTWBTCWETH
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.CONVEX_LDOETH_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.stkcvxLDOETH
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.CONVEX_TRI_CRV_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.stkcvxcrvUSDETHCRV
            })
        );
        convexBasePoolAdapters.push(
            ConvexBasePoolAdapter({
                targetContract: Contracts.AURA_B_RETH_STABLE_POOL,
                adapterType: AdapterType.CONVEX_V1_BASE_REWARD_POOL,
                stakedToken: Tokens.auraB_rETH_STABLE_vault
            })
        );
    }
}
