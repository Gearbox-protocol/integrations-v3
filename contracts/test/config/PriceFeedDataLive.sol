// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox.fi, 2021
pragma solidity ^0.8.10;

import { Tokens } from "./Tokens.sol";

import { Contracts } from "./SupportedContracts.sol";

struct ChainlinkPriceFeedData {
    Tokens token;
    address priceFeed;
}

struct CurvePriceFeedData {
    Tokens lpToken;
    Tokens[] assets;
    Contracts pool;
}

struct CurveLikePriceFeedData {
    Tokens lpToken;
    Tokens curveToken;
}

struct SingeTokenPriceFeedData {
    Tokens token;
}

contract PriceFeedDataLive {
    ChainlinkPriceFeedData[] chainlinkPriceFeeds;
    SingeTokenPriceFeedData[] zeroPriceFeeds;
    CurvePriceFeedData[] curvePriceFeeds;
    CurveLikePriceFeedData[] likeCurvePriceFeeds;
    SingeTokenPriceFeedData[] yearnPriceFeeds;
    SingeTokenPriceFeedData wstethPriceFeed;

    constructor(uint8 networkId) {
        if (networkId == 1) {
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens._1INCH,
                    priceFeed: 0xc929ad75B72593967DE83E7F7Cda0493458261D9
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.AAVE,
                    priceFeed: 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.COMP,
                    priceFeed: 0xdbd020CAeF83eFd542f4De03e3cF0C28A4428bd5
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.CRV,
                    priceFeed: 0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.DAI,
                    priceFeed: 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.DPI,
                    priceFeed: 0xD2A593BF7594aCE1faD597adb697b5645d5edDB2
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.FEI,
                    priceFeed: 0x31e0a88fecB6eC0a411DBe0e9E76391498296EE9
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.GUSD,
                    priceFeed: 0xa89f5d2365ce98B3cD68012b6f503ab1416245Fc
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.LINK,
                    priceFeed: 0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.SNX,
                    priceFeed: 0xDC3EA94CD0AC27d9A86C180091e7f78C683d3699
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.UNI,
                    priceFeed: 0x553303d460EE0afB37EdFf9bE42922D8FF63220e
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.USDC,
                    priceFeed: 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.USDT,
                    priceFeed: 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.WBTC,
                    priceFeed: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.WETH,
                    priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.YFI,
                    priceFeed: 0xA027702dbb89fbd58938e4324ac03B58d812b0E1
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.STETH,
                    priceFeed: 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.CVX,
                    priceFeed: 0xd962fC30A72A84cE50161031391756Bf2876Af5D
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.FRAX,
                    priceFeed: 0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.LUSD,
                    priceFeed: 0x3D7aE7E594f2f2091Ad8798313450130d0Aba3a0
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.sUSD,
                    priceFeed: 0xad35Bd71b9aFE6e4bDc266B345c198eaDEf9Ad94
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.FXS,
                    priceFeed: 0x6Ebc52C8C1089be9eB3945C4350B68B8E4C2233f
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.cvx3Crv,
                    curveToken: Tokens._3Crv
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.cvxcrvFRAX,
                    curveToken: Tokens.crvFRAX
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.cvxsteCRV,
                    curveToken: Tokens.steCRV
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.cvxFRAX3CRV,
                    curveToken: Tokens.FRAX3CRV
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.cvxLUSD3CRV,
                    curveToken: Tokens.LUSD3CRV
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.cvxcrvPlain3andSUSD,
                    curveToken: Tokens.crvPlain3andSUSD
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.cvxgusd3CRV,
                    curveToken: Tokens.gusd3CRV
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.stkcvx3Crv,
                    curveToken: Tokens._3Crv
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.stkcvxcrvFRAX,
                    curveToken: Tokens.crvFRAX
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.stkcvxsteCRV,
                    curveToken: Tokens.steCRV
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.stkcvxFRAX3CRV,
                    curveToken: Tokens.FRAX3CRV
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.stkcvxLUSD3CRV,
                    curveToken: Tokens.LUSD3CRV
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.stkcvxcrvPlain3andSUSD,
                    curveToken: Tokens.crvPlain3andSUSD
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.stkcvxgusd3CRV,
                    curveToken: Tokens.gusd3CRV
                })
            );
        } else if (networkId == 2) {
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens._1INCH,
                    priceFeed: 0x4813419C6783c36d10F97f08552310bf483fBD97
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.AAVE,
                    priceFeed: 0xEB24b7c2fB6497f28c937942439B4EAAE9535525
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.COMP,
                    priceFeed: 0xd31C7E8aa6871Fb09D5E01f17C54895F8237fB60
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.CRV,
                    priceFeed: 0x7f93084ECf52D4361A3E3E25F9Dafe005830C98C
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.DAI,
                    priceFeed: 0x1d34dd6780cC0B78aAfc8bC168e99ABEA147E85d
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.DPI,
                    priceFeed: 0xEA89a0168b9940b825B28CbF172B12c486a0FDf7
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.FEI,
                    priceFeed: 0xAF884aF60E28214233039c243F5DF98a52355CFB
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.GUSD,
                    priceFeed: 0x2C799CE9f858c9Fe0825D87ddd68F4dB46A485BE
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.LINK,
                    priceFeed: 0xa6fD8da40eCC3fd22cA8c13eF90B95cDf1346bEC
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.SNX,
                    priceFeed: 0xe19591bD0a702D0E46407a512885d2ce81fc63C8
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.UNI,
                    priceFeed: 0x9d5A93659c281dEBc71ADB719f19999BfdCD4177
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.USDC,
                    priceFeed: 0xC24EC8bD3441da32f06BfEd3A4778133ad48a665
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.USDT,
                    priceFeed: 0x45a963a68848a850262Cb5aa1F5Be7dC4a6f0Abd
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.WBTC,
                    priceFeed: 0x048F634279BE1CC4De3F17fD4c31101bAD0826c8
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.WETH,
                    priceFeed: 0x491741d9F426130d1bC27Aee82f8b4Bd4E6E5f5D
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.YFI,
                    priceFeed: 0x2d764833c4985A90Beb7DB43d4FFAD5Bb9675B9e
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.STETH,
                    priceFeed: 0xf4f054C2E3269730c781dc7e1Fe2a3ca745784bd
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.CVX,
                    priceFeed: 0xF958760fd9c0E019e355f31c3D69f0E5239597D0
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.FRAX,
                    priceFeed: 0xC095CEa800dBAdcCc742124b68399Ac6ADF5d8eC
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.LUSD,
                    priceFeed: 0xd6852347062aB885B6Fb9F7220BedCc5A39CE862
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.sUSD,
                    priceFeed: 0x725F188BF87DaF7A7c3de39276ad78a2b8559793
                })
            );
            chainlinkPriceFeeds.push(
                ChainlinkPriceFeedData({
                    token: Tokens.FXS,
                    priceFeed: 0x2E49F1FbBdA0000E89376D3332A1d42dBeF3D205
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.cvx3Crv,
                    curveToken: Tokens._3Crv
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.cvxcrvFRAX,
                    curveToken: Tokens.crvFRAX
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.cvxsteCRV,
                    curveToken: Tokens.steCRV
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.cvxFRAX3CRV,
                    curveToken: Tokens.FRAX3CRV
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.cvxLUSD3CRV,
                    curveToken: Tokens.LUSD3CRV
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.cvxcrvPlain3andSUSD,
                    curveToken: Tokens.crvPlain3andSUSD
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.cvxgusd3CRV,
                    curveToken: Tokens.gusd3CRV
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.stkcvx3Crv,
                    curveToken: Tokens._3Crv
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.stkcvxcrvFRAX,
                    curveToken: Tokens.crvFRAX
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.stkcvxsteCRV,
                    curveToken: Tokens.steCRV
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.stkcvxFRAX3CRV,
                    curveToken: Tokens.FRAX3CRV
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.stkcvxLUSD3CRV,
                    curveToken: Tokens.LUSD3CRV
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.stkcvxcrvPlain3andSUSD,
                    curveToken: Tokens.crvPlain3andSUSD
                })
            );
            likeCurvePriceFeeds.push(
                CurveLikePriceFeedData({
                    lpToken: Tokens.stkcvxgusd3CRV,
                    curveToken: Tokens.gusd3CRV
                })
            );
        }

        zeroPriceFeeds.push(SingeTokenPriceFeedData({ token: Tokens.LDO }));
        zeroPriceFeeds.push(SingeTokenPriceFeedData({ token: Tokens.LQTY }));
        curvePriceFeeds.push(
            CurvePriceFeedData({
                lpToken: Tokens._3Crv,
                assets: assets(Tokens.DAI, Tokens.USDC, Tokens.USDT),
                pool: Contracts.CURVE_3CRV_POOL
            })
        );
        curvePriceFeeds.push(
            CurvePriceFeedData({
                lpToken: Tokens.crvFRAX,
                assets: assets(Tokens.FRAX, Tokens.USDC),
                pool: Contracts.CURVE_FRAX_USDC_POOL
            })
        );
        curvePriceFeeds.push(
            CurvePriceFeedData({
                lpToken: Tokens.steCRV,
                assets: assets(Tokens.STETH, Tokens.WETH),
                pool: Contracts.CURVE_STETH_GATEWAY
            })
        );
        curvePriceFeeds.push(
            CurvePriceFeedData({
                lpToken: Tokens.FRAX3CRV,
                assets: assets(
                    Tokens.FRAX,
                    Tokens.DAI,
                    Tokens.USDC,
                    Tokens.USDT
                ),
                pool: Contracts.CURVE_FRAX_POOL
            })
        );
        curvePriceFeeds.push(
            CurvePriceFeedData({
                lpToken: Tokens.LUSD3CRV,
                assets: assets(
                    Tokens.LUSD,
                    Tokens.DAI,
                    Tokens.USDC,
                    Tokens.USDT
                ),
                pool: Contracts.CURVE_LUSD_POOL
            })
        );
        curvePriceFeeds.push(
            CurvePriceFeedData({
                lpToken: Tokens.crvPlain3andSUSD,
                assets: assets(
                    Tokens.DAI,
                    Tokens.USDC,
                    Tokens.USDT,
                    Tokens.sUSD
                ),
                pool: Contracts.CURVE_SUSD_POOL
            })
        );
        curvePriceFeeds.push(
            CurvePriceFeedData({
                lpToken: Tokens.gusd3CRV,
                assets: assets(
                    Tokens.GUSD,
                    Tokens.DAI,
                    Tokens.USDC,
                    Tokens.USDT
                ),
                pool: Contracts.CURVE_GUSD_POOL
            })
        );
        yearnPriceFeeds.push(SingeTokenPriceFeedData({ token: Tokens.yvDAI }));
        yearnPriceFeeds.push(SingeTokenPriceFeedData({ token: Tokens.yvUSDC }));
        yearnPriceFeeds.push(SingeTokenPriceFeedData({ token: Tokens.yvWETH }));
        yearnPriceFeeds.push(SingeTokenPriceFeedData({ token: Tokens.yvWBTC }));
        yearnPriceFeeds.push(
            SingeTokenPriceFeedData({ token: Tokens.yvCurve_stETH })
        );
        yearnPriceFeeds.push(
            SingeTokenPriceFeedData({ token: Tokens.yvCurve_FRAX })
        );
        wstethPriceFeed = SingeTokenPriceFeedData({ token: Tokens.wstETH });
    }

    function assets(Tokens t1, Tokens t2)
        internal
        pure
        returns (Tokens[] memory result)
    {
        result = new Tokens[](2);
        result[0] = t1;
        result[1] = t2;
    }

    function assets(
        Tokens t1,
        Tokens t2,
        Tokens t3
    ) internal pure returns (Tokens[] memory result) {
        result = new Tokens[](3);
        result[0] = t1;
        result[1] = t2;
        result[2] = t3;
    }

    function assets(
        Tokens t1,
        Tokens t2,
        Tokens t3,
        Tokens t4
    ) internal pure returns (Tokens[] memory result) {
        result = new Tokens[](4);
        result[0] = t1;
        result[1] = t2;
        result[2] = t3;
        result[3] = t4;
    }
}
