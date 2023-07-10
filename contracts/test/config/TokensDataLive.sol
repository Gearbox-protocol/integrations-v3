// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {Tokens} from "./Tokens.sol";
import {TokenData} from "../suites/TokensTestSuite.sol";
import {TokenType} from "../../integrations/TokenType.sol";

contract TokensDataLive {
    TokenData[] tokenData;

    constructor(uint8 networkId) {
        TokenData[] memory td;

        if (networkId == 1) {
            td = new TokenData[](83);
            td[0] = TokenData({
                id: Tokens._1INCH,
                addr: 0x111111111117dC0aa78b770fA6A738034120C302,
                symbol: "1INCH",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[1] = TokenData({
                id: Tokens.AAVE,
                addr: 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9,
                symbol: "AAVE",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[2] = TokenData({
                id: Tokens.COMP,
                addr: 0xc00e94Cb662C3520282E6f5717214004A7f26888,
                symbol: "COMP",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[3] = TokenData({
                id: Tokens.CRV,
                addr: 0xD533a949740bb3306d119CC777fa900bA034cd52,
                symbol: "CRV",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[4] = TokenData({
                id: Tokens.DAI,
                addr: 0x6B175474E89094C44Da98b954EedeAC495271d0F,
                symbol: "DAI",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[5] = TokenData({
                id: Tokens.DPI,
                addr: 0x1494CA1F11D487c2bBe4543E90080AeBa4BA3C2b,
                symbol: "DPI",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[6] = TokenData({
                id: Tokens.FEI,
                addr: 0x956F47F50A910163D8BF957Cf5846D573E7f87CA,
                symbol: "FEI",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[7] = TokenData({
                id: Tokens.LINK,
                addr: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
                symbol: "LINK",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[8] = TokenData({
                id: Tokens.SNX,
                addr: 0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F,
                symbol: "SNX",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[9] = TokenData({
                id: Tokens.UNI,
                addr: 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984,
                symbol: "UNI",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[10] = TokenData({
                id: Tokens.USDC,
                addr: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                symbol: "USDC",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[11] = TokenData({
                id: Tokens.USDT,
                addr: 0xdAC17F958D2ee523a2206206994597C13D831ec7,
                symbol: "USDT",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[12] = TokenData({
                id: Tokens.WBTC,
                addr: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
                symbol: "WBTC",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[13] = TokenData({
                id: Tokens.WETH,
                addr: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
                symbol: "WETH",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[14] = TokenData({
                id: Tokens.YFI,
                addr: 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e,
                symbol: "YFI",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[15] = TokenData({
                id: Tokens.STETH,
                addr: 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84,
                symbol: "STETH",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[16] = TokenData({
                id: Tokens.wstETH,
                addr: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
                symbol: "wstETH",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[17] = TokenData({
                id: Tokens.CVX,
                addr: 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B,
                symbol: "CVX",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[18] = TokenData({
                id: Tokens.FRAX,
                addr: 0x853d955aCEf822Db058eb8505911ED77F175b99e,
                symbol: "FRAX",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[19] = TokenData({
                id: Tokens.FXS,
                addr: 0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0,
                symbol: "FXS",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[20] = TokenData({
                id: Tokens.LDO,
                addr: 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32,
                symbol: "LDO",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[21] = TokenData({
                id: Tokens.LUSD,
                addr: 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0,
                symbol: "LUSD",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[22] = TokenData({
                id: Tokens.sUSD,
                addr: 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51,
                symbol: "sUSD",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[23] = TokenData({
                id: Tokens.GUSD,
                addr: 0x056Fd409E1d7A124BD7017459dFEa2F387b6d5Cd,
                symbol: "GUSD",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[24] = TokenData({
                id: Tokens.LQTY,
                addr: 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D,
                symbol: "LQTY",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[25] = TokenData({
                id: Tokens.OHM,
                addr: 0x64aa3364F17a4D01c6f1751Fd97C2BD3D7e7f1D5,
                symbol: "OHM",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[26] = TokenData({
                id: Tokens.MIM,
                addr: 0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3,
                symbol: "MIM",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[27] = TokenData({
                id: Tokens.SPELL,
                addr: 0x090185f2135308BaD17527004364eBcC2D37e5F6,
                symbol: "SPELL",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[28] = TokenData({
                id: Tokens._3Crv,
                addr: 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490,
                symbol: "3Crv",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[29] = TokenData({
                id: Tokens.crvFRAX,
                addr: 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC,
                symbol: "crvFRAX",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[30] = TokenData({
                id: Tokens.steCRV,
                addr: 0x06325440D014e39736583c165C2963BA99fAf14E,
                symbol: "steCRV",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[31] = TokenData({
                id: Tokens.crvPlain3andSUSD,
                addr: 0xC25a3A3b969415c80451098fa907EC722572917F,
                symbol: "crvPlain3andSUSD",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[32] = TokenData({
                id: Tokens.OHMFRAXBP,
                addr: 0x5271045F7B73c17825A7A7aee6917eE46b0B7520,
                symbol: "OHMFRAXBP",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[33] = TokenData({
                id: Tokens.crvCRVETH,
                addr: 0xEd4064f376cB8d68F770FB1Ff088a3d0F3FF5c4d,
                symbol: "crvCRVETH",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[34] = TokenData({
                id: Tokens.crvCVXETH,
                addr: 0x3A283D9c08E8b55966afb64C515f5143cf907611,
                symbol: "crvCVXETH",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[35] = TokenData({
                id: Tokens.crvUSDTWBTCWETH,
                addr: 0xf5f5B97624542D72A9E06f04804Bf81baA15e2B4,
                symbol: "crvUSDTWBTCWETH",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[36] = TokenData({
                id: Tokens.LDOETH,
                addr: 0xb79565c01b7Ae53618d9B847b9443aAf4f9011e7,
                symbol: "LDOETH",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[37] = TokenData({
                id: Tokens.FRAX3CRV,
                addr: 0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B,
                symbol: "FRAX3CRV",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[38] = TokenData({
                id: Tokens.LUSD3CRV,
                addr: 0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA,
                symbol: "LUSD3CRV",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[39] = TokenData({
                id: Tokens.gusd3CRV,
                addr: 0xD2967f45c4f384DEEa880F807Be904762a3DeA07,
                symbol: "gusd3CRV",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[40] = TokenData({
                id: Tokens.MIM_3LP3CRV,
                addr: 0x5a6A4D54456819380173272A5E8E9B9904BdF41B,
                symbol: "MIM_3LP3CRV",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[41] = TokenData({
                id: Tokens.cvx3Crv,
                addr: 0x30D9410ED1D5DA1F6C8391af5338C93ab8d4035C,
                symbol: "cvx3Crv",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[42] = TokenData({
                id: Tokens.cvxcrvFRAX,
                addr: 0x117A0bab81F25e60900787d98061cCFae023560c,
                symbol: "cvxcrvFRAX",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[43] = TokenData({
                id: Tokens.cvxsteCRV,
                addr: 0x9518c9063eB0262D791f38d8d6Eb0aca33c63ed0,
                symbol: "cvxsteCRV",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[44] = TokenData({
                id: Tokens.cvxFRAX3CRV,
                addr: 0xbE0F6478E0E4894CFb14f32855603A083A57c7dA,
                symbol: "cvxFRAX3CRV",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[45] = TokenData({
                id: Tokens.cvxLUSD3CRV,
                addr: 0xFB9B2f06FDb404Fd3E2278E9A9edc8f252F273d0,
                symbol: "cvxLUSD3CRV",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[46] = TokenData({
                id: Tokens.cvxcrvPlain3andSUSD,
                addr: 0x11D200ef1409cecA8D6d23e6496550f707772F11,
                symbol: "cvxcrvPlain3andSUSD",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[47] = TokenData({
                id: Tokens.cvxgusd3CRV,
                addr: 0x15c2471ef46Fa721990730cfa526BcFb45574576,
                symbol: "cvxgusd3CRV",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[48] = TokenData({
                id: Tokens.cvxOHMFRAXBP,
                addr: 0xd8F1B275c320819c7D752ef79988d0780bf00446,
                symbol: "cvxOHMFRAXBP",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[49] = TokenData({
                id: Tokens.cvxMIM_3LP3CRV,
                addr: 0xabB54222c2b77158CC975a2b715a3d703c256F05,
                symbol: "cvxMIM_3LP3CRV",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[50] = TokenData({
                id: Tokens.cvxcrvCRVETH,
                addr: 0x0Fb8dcdD95e4C48D3dD0eFA4086512f6F8FD4565,
                symbol: "cvxcrvCRVETH",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[51] = TokenData({
                id: Tokens.cvxcrvCVXETH,
                addr: 0x0bC857f97c0554d1d0D602b56F2EEcE682016fBA,
                symbol: "cvxcrvCVXETH",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[52] = TokenData({
                id: Tokens.cvxcrvUSDTWBTCWETH,
                addr: 0xB77BA8B4b9d981269466eE95796A9Af57d4E82DB,
                symbol: "cvxcrvUSDTWBTCWETH",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[53] = TokenData({
                id: Tokens.cvxLDOETH,
                addr: 0xD533a949740bb3306d119CC777fa900bA034cd52,
                symbol: "cvxLDOETH",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[54] = TokenData({
                id: Tokens.stkcvx3Crv,
                addr: 0xbAc7a431146aeAf3F57A16b9954f332Fd292F270,
                symbol: "stkcvx3Crv",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[55] = TokenData({
                id: Tokens.stkcvxcrvFRAX,
                addr: 0x276187f24D41745513cbE2Bd5dFC33a4d8CDc9ed,
                symbol: "stkcvxcrvFRAX",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[56] = TokenData({
                id: Tokens.stkcvxsteCRV,
                addr: 0xe15B7D80a51e1fe54aC355CaBE848Efce5289BDB,
                symbol: "stkcvxsteCRV",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[57] = TokenData({
                id: Tokens.stkcvxFRAX3CRV,
                addr: 0xaF314b088B53835d5cF4e4CB81beABa5934a61fe,
                symbol: "stkcvxFRAX3CRV",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[58] = TokenData({
                id: Tokens.stkcvxLUSD3CRV,
                addr: 0x0A1D4A25d0390899b90bCD22E1Ef155003EA76d7,
                symbol: "stkcvxLUSD3CRV",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[59] = TokenData({
                id: Tokens.stkcvxcrvPlain3andSUSD,
                addr: 0x7e1992A7F28dAA5f6a2d34e2cd40f962f37B172C,
                symbol: "stkcvxcrvPlain3andSUSD",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[60] = TokenData({
                id: Tokens.stkcvxgusd3CRV,
                addr: 0x34fB99abBAFb4e87e256960D572664c6ADc301B8,
                symbol: "stkcvxgusd3CRV",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[61] = TokenData({
                id: Tokens.stkcvxOHMFRAXBP,
                addr: 0x888407AabAfa936B90acF65C4Db19370A01d9bd8,
                symbol: "stkcvxOHMFRAXBP",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[62] = TokenData({
                id: Tokens.stkcvxMIM_3LP3CRV,
                addr: 0x1aAbe1B22a290cCB39FD77440D5eb96Cf40079f4,
                symbol: "stkcvxMIM_3LP3CRV",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[63] = TokenData({
                id: Tokens.stkcvxcrvCRVETH,
                addr: 0xfC4b109D46e12170DF31AF8ba39403fAC2b8c0cf,
                symbol: "stkcvxcrvCRVETH",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[64] = TokenData({
                id: Tokens.stkcvxcrvCVXETH,
                addr: 0x948bEd0211076b05d22e98929217d0f04D068C5c,
                symbol: "stkcvxcrvCVXETH",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[65] = TokenData({
                id: Tokens.stkcvxcrvUSDTWBTCWETH,
                addr: 0xEE3EE8373384BBfea3227E527C1B9b4e7821273E,
                symbol: "stkcvxcrvUSDTWBTCWETH",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[66] = TokenData({
                id: Tokens.stkcvxLDOETH,
                addr: 0x2Fd6bD5b81c1060039D619E76e4e1f924B173006,
                symbol: "stkcvxLDOETH",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[67] = TokenData({
                id: Tokens.yvDAI,
                addr: 0xdA816459F1AB5631232FE5e97a05BBBb94970c95,
                symbol: "yvDAI",
                tokenType: TokenType.YEARN_ON_NORMAL_TOKEN
            });
            td[68] = TokenData({
                id: Tokens.yvUSDC,
                addr: 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE,
                symbol: "yvUSDC",
                tokenType: TokenType.YEARN_ON_NORMAL_TOKEN
            });
            td[69] = TokenData({
                id: Tokens.yvWETH,
                addr: 0xa258C4606Ca8206D8aA700cE2143D7db854D168c,
                symbol: "yvWETH",
                tokenType: TokenType.YEARN_ON_NORMAL_TOKEN
            });
            td[70] = TokenData({
                id: Tokens.yvWBTC,
                addr: 0xA696a63cc78DfFa1a63E9E50587C197387FF6C7E,
                symbol: "yvWBTC",
                tokenType: TokenType.YEARN_ON_NORMAL_TOKEN
            });
            td[71] = TokenData({
                id: Tokens.yvCurve_stETH,
                addr: 0xdCD90C7f6324cfa40d7169ef80b12031770B4325,
                symbol: "yvCurve_stETH",
                tokenType: TokenType.YEARN_ON_CURVE_TOKEN
            });
            td[72] = TokenData({
                id: Tokens.yvCurve_FRAX,
                addr: 0xB4AdA607B9d6b2c9Ee07A275e9616B84AC560139,
                symbol: "yvCurve_FRAX",
                tokenType: TokenType.YEARN_ON_CURVE_TOKEN
            });
            td[73] = TokenData({
                id: Tokens._50OHM_50DAI,
                addr: 0x76FCf0e8C7Ff37A47a799FA2cd4c13cDe0D981C9,
                symbol: "50OHM_50DAI",
                tokenType: TokenType.BALANCER_LP_TOKEN
            });
            td[74] = TokenData({
                id: Tokens._50OHM_50WETH,
                addr: 0xD1eC5e215E8148D76F4460e4097FD3d5ae0A3558,
                symbol: "50OHM_50WETH",
                tokenType: TokenType.BALANCER_LP_TOKEN
            });
            td[75] = TokenData({
                id: Tokens.OHM_wstETH,
                addr: 0xd4f79CA0Ac83192693bce4699d0c10C66Aa6Cf0F,
                symbol: "OHM_wstETH",
                tokenType: TokenType.BALANCER_LP_TOKEN
            });
            td[76] = TokenData({
                id: Tokens.dDAI,
                addr: 0x6CFaF95457d7688022FC53e7AbE052ef8DFBbdBA,
                symbol: "dDAI",
                tokenType: TokenType.DIESEL_LP_TOKEN
            });
            td[77] = TokenData({
                id: Tokens.dUSDC,
                addr: 0xc411dB5f5Eb3f7d552F9B8454B2D74097ccdE6E3,
                symbol: "dUSDC",
                tokenType: TokenType.DIESEL_LP_TOKEN
            });
            td[78] = TokenData({
                id: Tokens.dWBTC,
                addr: 0xe753260F1955e8678DCeA8887759e07aa57E8c54,
                symbol: "dWBTC",
                tokenType: TokenType.DIESEL_LP_TOKEN
            });
            td[79] = TokenData({
                id: Tokens.dWETH,
                addr: 0xF21fc650C1B34eb0FDE786D52d23dA99Db3D6278,
                symbol: "dWETH",
                tokenType: TokenType.DIESEL_LP_TOKEN
            });
            td[80] = TokenData({
                id: Tokens.dwstETH,
                addr: 0x2158034dB06f06dcB9A786D2F1F8c38781bA779d,
                symbol: "dwstETH",
                tokenType: TokenType.DIESEL_LP_TOKEN
            });
            td[81] = TokenData({
                id: Tokens.dFRAX,
                addr: 0x8A1112AFef7F4FC7c066a77AABBc01b3Fff31D47,
                symbol: "dFRAX",
                tokenType: TokenType.DIESEL_LP_TOKEN
            });
            td[82] = TokenData({
                id: Tokens.GEAR,
                addr: 0xBa3335588D9403515223F109EdC4eB7269a9Ab5D,
                symbol: "GEAR",
                tokenType: TokenType.GEAR_TOKEN
            });
        } else if (networkId == 2) {
            td = new TokenData[](83);
            td[0] = TokenData({
                id: Tokens._1INCH,
                addr: 0xC69D4e2940950bf26977b421BDB9a06F40D37db4,
                symbol: "1INCH",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[1] = TokenData({
                id: Tokens.AAVE,
                addr: 0xc28667333f193e0cfD69E8fbC60CC6cB875414fA,
                symbol: "AAVE",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[2] = TokenData({
                id: Tokens.COMP,
                addr: 0xaDa57f2C1Ba941509ffF0eEb7e846C95A5933951,
                symbol: "COMP",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[3] = TokenData({
                id: Tokens.CRV,
                addr: 0x976d27eC7ebb1136cd7770F5e06aC917Aa9C672b,
                symbol: "CRV",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[4] = TokenData({
                id: Tokens.DAI,
                addr: 0x55a309598ABf543bF76FbB22859938ba2F29C2eA,
                symbol: "DAI",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[5] = TokenData({
                id: Tokens.DPI,
                addr: 0x130874718AfcC298894e0a60a1b87c9C2989C2E6,
                symbol: "DPI",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[6] = TokenData({
                id: Tokens.FEI,
                addr: 0x49FCC2B5978839FAB2E0364C8ed4be222689f1aF,
                symbol: "FEI",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[7] = TokenData({
                id: Tokens.LINK,
                addr: 0x609CeB4781A3A37C81122FD69b20dc5155dABe0B,
                symbol: "LINK",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[8] = TokenData({
                id: Tokens.SNX,
                addr: 0x293177E8F7DEA75e44C6799e975A42222cBB326B,
                symbol: "SNX",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[9] = TokenData({
                id: Tokens.UNI,
                addr: 0xd354fEF0E34ef0ee467d61eee5Af8336fd36Cb7D,
                symbol: "UNI",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[10] = TokenData({
                id: Tokens.USDC,
                addr: 0x1F2cd0D7E5a7d8fE41f886063E9F11A05dE217Fa,
                symbol: "USDC",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[11] = TokenData({
                id: Tokens.USDT,
                addr: 0xc81c248c44e96D85a0eCddc104843cE55B1ff35c,
                symbol: "USDT",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[12] = TokenData({
                id: Tokens.WBTC,
                addr: 0x34852e54D9B4Ec4325C7344C28b584Ce972e5E62,
                symbol: "WBTC",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[13] = TokenData({
                id: Tokens.WETH,
                addr: 0x595DFFf822767c2E14CFB7D5e0b5a5e23eCfACdd,
                symbol: "WETH",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[14] = TokenData({
                id: Tokens.YFI,
                addr: 0xCad5D7701e0A85fe50B3aCaBDcdF7e75672F326e,
                symbol: "YFI",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[15] = TokenData({
                id: Tokens.STETH,
                addr: 0xd628baa42b3080593a231016bF3F229161C9F745,
                symbol: "STETH",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[16] = TokenData({
                id: Tokens.wstETH,
                addr: 0x5E590e6c887A84098F3fa465267a44AaE058eBbb,
                symbol: "wstETH",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[17] = TokenData({
                id: Tokens.CVX,
                addr: 0x6D75eb70402CF06a0cB5B8fdc1836dAe29702B17,
                symbol: "CVX",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[18] = TokenData({
                id: Tokens.FRAX,
                addr: 0x92d43093959C7DDa89896418bCE9DE0B87879646,
                symbol: "FRAX",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[19] = TokenData({
                id: Tokens.FXS,
                addr: 0x34C035818Dd308f3aC20e68bC03C3E4FC8924d9d,
                symbol: "FXS",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[20] = TokenData({
                id: Tokens.LDO,
                addr: 0x13781b54cd88cC115a17Db53b058706B29FaD341,
                symbol: "LDO",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[21] = TokenData({
                id: Tokens.LUSD,
                addr: 0xF1D178615E7BB6a7331EE73F84D5Ac6c95d8BC91,
                symbol: "LUSD",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[22] = TokenData({
                id: Tokens.sUSD,
                addr: 0x4F02e25531520709114e470f45A1Fb50862e3147,
                symbol: "sUSD",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[23] = TokenData({
                id: Tokens.GUSD,
                addr: 0x50688e51B3941BFdf6a878F810dAF85bFc0657cf,
                symbol: "GUSD",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[24] = TokenData({
                id: Tokens.LQTY,
                addr: 0x7f5E8e47d982052bD6A1CA26551b80821802847d,
                symbol: "LQTY",
                tokenType: TokenType.NORMAL_TOKEN
            });
            td[25] = TokenData({id: Tokens.OHM, addr: address(0), symbol: "OHM", tokenType: TokenType.NORMAL_TOKEN});
            td[26] = TokenData({id: Tokens.MIM, addr: address(0), symbol: "MIM", tokenType: TokenType.NORMAL_TOKEN});
            td[27] = TokenData({id: Tokens.SPELL, addr: address(0), symbol: "SPELL", tokenType: TokenType.NORMAL_TOKEN});
            td[28] = TokenData({
                id: Tokens._3Crv,
                addr: 0xb2f394A64966a8892a43CcfBBD48D28bC58Aeb67,
                symbol: "3Crv",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[29] = TokenData({
                id: Tokens.crvFRAX,
                addr: 0xBE72A443c81Ca75B96039C68B335F1f8c6bA48E9,
                symbol: "crvFRAX",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[30] = TokenData({
                id: Tokens.steCRV,
                addr: 0xf5c5e39F56fF90C0F63a97F3c77779eF495c1faD,
                symbol: "steCRV",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[31] = TokenData({
                id: Tokens.crvPlain3andSUSD,
                addr: 0xC3d328CCA12347A31126d891D16fe8C5466625a5,
                symbol: "crvPlain3andSUSD",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[32] = TokenData({
                id: Tokens.OHMFRAXBP,
                addr: address(0),
                symbol: "OHMFRAXBP",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[33] = TokenData({
                id: Tokens.crvCRVETH,
                addr: address(0),
                symbol: "crvCRVETH",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[34] = TokenData({
                id: Tokens.crvCVXETH,
                addr: address(0),
                symbol: "crvCVXETH",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[35] = TokenData({
                id: Tokens.crvUSDTWBTCWETH,
                addr: address(0),
                symbol: "crvUSDTWBTCWETH",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[36] =
                TokenData({id: Tokens.LDOETH, addr: address(0), symbol: "LDOETH", tokenType: TokenType.CURVE_LP_TOKEN});
            td[37] = TokenData({
                id: Tokens.FRAX3CRV,
                addr: 0x12Ad3125C67eC5325Cc94AFdA8B26cd12BCe1E9b,
                symbol: "FRAX3CRV",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[38] = TokenData({
                id: Tokens.LUSD3CRV,
                addr: 0x348B1846b87cA12D23A9A4E73B1CfAc2Aad49cf4,
                symbol: "LUSD3CRV",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[39] = TokenData({
                id: Tokens.gusd3CRV,
                addr: 0xbD919fcC47ae2b5Cc2fe646971aCcB1e88843DC5,
                symbol: "gusd3CRV",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[40] = TokenData({
                id: Tokens.MIM_3LP3CRV,
                addr: address(0),
                symbol: "MIM_3LP3CRV",
                tokenType: TokenType.CURVE_LP_TOKEN
            });
            td[41] = TokenData({
                id: Tokens.cvx3Crv,
                addr: 0xe12bFD868a81D1AD147731D0eC164d9C4A397FCd,
                symbol: "cvx3Crv",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[42] = TokenData({
                id: Tokens.cvxcrvFRAX,
                addr: 0x68345E6C192f97A7334a96ceda94e2486c08Fa0c,
                symbol: "cvxcrvFRAX",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[43] = TokenData({
                id: Tokens.cvxsteCRV,
                addr: 0xF0258e3527726f641056a2F7DA08637a1d67422E,
                symbol: "cvxsteCRV",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[44] = TokenData({
                id: Tokens.cvxFRAX3CRV,
                addr: 0x17181501B6986CE1e4efD9A9Df9975aD24b0c543,
                symbol: "cvxFRAX3CRV",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[45] = TokenData({
                id: Tokens.cvxLUSD3CRV,
                addr: 0xD944F38aa81804313db028924Cf0695B26B67e6E,
                symbol: "cvxLUSD3CRV",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[46] = TokenData({
                id: Tokens.cvxcrvPlain3andSUSD,
                addr: 0xaB54a40e7Fd2aD82c07958BF6AA3395CEAb078b5,
                symbol: "cvxcrvPlain3andSUSD",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[47] = TokenData({
                id: Tokens.cvxgusd3CRV,
                addr: 0xBA9e6B05b0F2C5B41Df2d56c0b1ddaFa03d53fed,
                symbol: "cvxgusd3CRV",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[48] = TokenData({
                id: Tokens.cvxOHMFRAXBP,
                addr: address(0),
                symbol: "cvxOHMFRAXBP",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[49] = TokenData({
                id: Tokens.cvxMIM_3LP3CRV,
                addr: address(0),
                symbol: "cvxMIM_3LP3CRV",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[50] = TokenData({
                id: Tokens.cvxcrvCRVETH,
                addr: address(0),
                symbol: "cvxcrvCRVETH",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[51] = TokenData({
                id: Tokens.cvxcrvCVXETH,
                addr: address(0),
                symbol: "cvxcrvCVXETH",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[52] = TokenData({
                id: Tokens.cvxcrvUSDTWBTCWETH,
                addr: address(0),
                symbol: "cvxcrvUSDTWBTCWETH",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[53] = TokenData({
                id: Tokens.cvxLDOETH,
                addr: address(0),
                symbol: "cvxLDOETH",
                tokenType: TokenType.CONVEX_LP_TOKEN
            });
            td[54] = TokenData({
                id: Tokens.stkcvx3Crv,
                addr: 0xEB763389772eA09eddFcfed3EC571Bb20c187763,
                symbol: "stkcvx3Crv",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[55] = TokenData({
                id: Tokens.stkcvxcrvFRAX,
                addr: 0x6784ED28285ECd58F76f3A85F39A293E15080964,
                symbol: "stkcvxcrvFRAX",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[56] = TokenData({
                id: Tokens.stkcvxsteCRV,
                addr: 0x3AE88c07D9A9b48706d7ea197aD53d30578ACdA1,
                symbol: "stkcvxsteCRV",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[57] = TokenData({
                id: Tokens.stkcvxFRAX3CRV,
                addr: 0x6fd7C6c0362E836eab644fD1E1D09a9e3836e62C,
                symbol: "stkcvxFRAX3CRV",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[58] = TokenData({
                id: Tokens.stkcvxLUSD3CRV,
                addr: 0x84c04976BA15AE880B8D6daC9CE1075D0eFD0d4D,
                symbol: "stkcvxLUSD3CRV",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[59] = TokenData({
                id: Tokens.stkcvxcrvPlain3andSUSD,
                addr: 0x49416516604eF33383Bd9F3a94fEcd4ee36E2d88,
                symbol: "stkcvxcrvPlain3andSUSD",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[60] = TokenData({
                id: Tokens.stkcvxgusd3CRV,
                addr: 0x6Ca199719B8d6b8406387DC18a29eC13dD725Ed6,
                symbol: "stkcvxgusd3CRV",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[61] = TokenData({
                id: Tokens.stkcvxOHMFRAXBP,
                addr: address(0),
                symbol: "stkcvxOHMFRAXBP",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[62] = TokenData({
                id: Tokens.stkcvxMIM_3LP3CRV,
                addr: address(0),
                symbol: "stkcvxMIM_3LP3CRV",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[63] = TokenData({
                id: Tokens.stkcvxcrvCRVETH,
                addr: address(0),
                symbol: "stkcvxcrvCRVETH",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[64] = TokenData({
                id: Tokens.stkcvxcrvCVXETH,
                addr: address(0),
                symbol: "stkcvxcrvCVXETH",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[65] = TokenData({
                id: Tokens.stkcvxcrvUSDTWBTCWETH,
                addr: address(0),
                symbol: "stkcvxcrvUSDTWBTCWETH",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[66] = TokenData({
                id: Tokens.stkcvxLDOETH,
                addr: address(0),
                symbol: "stkcvxLDOETH",
                tokenType: TokenType.CONVEX_STAKED_TOKEN
            });
            td[67] = TokenData({
                id: Tokens.yvDAI,
                addr: 0xAAC67551F8d1D052E375BaCf774b494850BBca87,
                symbol: "yvDAI",
                tokenType: TokenType.YEARN_ON_NORMAL_TOKEN
            });
            td[68] = TokenData({
                id: Tokens.yvUSDC,
                addr: 0x05724F02a0270F08E525F2681afA9173957c505e,
                symbol: "yvUSDC",
                tokenType: TokenType.YEARN_ON_NORMAL_TOKEN
            });
            td[69] = TokenData({
                id: Tokens.yvWETH,
                addr: 0xEe8Adf657c5EF8e10622b6B47014D2C6f6993E5E,
                symbol: "yvWETH",
                tokenType: TokenType.YEARN_ON_NORMAL_TOKEN
            });
            td[70] = TokenData({
                id: Tokens.yvWBTC,
                addr: 0x683fcBf347b90C652b4B07648180C0b54c258815,
                symbol: "yvWBTC",
                tokenType: TokenType.YEARN_ON_NORMAL_TOKEN
            });
            td[71] = TokenData({
                id: Tokens.yvCurve_stETH,
                addr: 0x2681AFa48aCFC2Ae5308bf6127d2fb563763f13E,
                symbol: "yvCurve_stETH",
                tokenType: TokenType.YEARN_ON_CURVE_TOKEN
            });
            td[72] = TokenData({
                id: Tokens.yvCurve_FRAX,
                addr: 0x43d45AEf2BAb5fa79e3bBDb2dB7E4443B8123C8f,
                symbol: "yvCurve_FRAX",
                tokenType: TokenType.YEARN_ON_CURVE_TOKEN
            });
            td[73] = TokenData({
                id: Tokens._50OHM_50DAI,
                addr: address(0),
                symbol: "50OHM_50DAI",
                tokenType: TokenType.BALANCER_LP_TOKEN
            });
            td[74] = TokenData({
                id: Tokens._50OHM_50WETH,
                addr: address(0),
                symbol: "50OHM_50WETH",
                tokenType: TokenType.BALANCER_LP_TOKEN
            });
            td[75] = TokenData({
                id: Tokens.OHM_wstETH,
                addr: address(0),
                symbol: "OHM_wstETH",
                tokenType: TokenType.BALANCER_LP_TOKEN
            });
            td[76] = TokenData({
                id: Tokens.dDAI,
                addr: 0x1726d8a1d3193D7C5A301Bb64b025cBD91BA791c,
                symbol: "dDAI",
                tokenType: TokenType.DIESEL_LP_TOKEN
            });
            td[77] = TokenData({
                id: Tokens.dUSDC,
                addr: 0x5bBDBDa8cE49B152ae48FB37F2397A5EBF35d59C,
                symbol: "dUSDC",
                tokenType: TokenType.DIESEL_LP_TOKEN
            });
            td[78] = TokenData({
                id: Tokens.dWBTC,
                addr: 0xd7f208de8d5b5301e7018dcc6D312A4305382330,
                symbol: "dWBTC",
                tokenType: TokenType.DIESEL_LP_TOKEN
            });
            td[79] = TokenData({
                id: Tokens.dWETH,
                addr: 0xfb906E19E71ED61bcb5eA0E11d77941A058eafBD,
                symbol: "dWETH",
                tokenType: TokenType.DIESEL_LP_TOKEN
            });
            td[80] = TokenData({
                id: Tokens.dwstETH,
                addr: 0xAB20D04aF0f79aB21cC66431F6BAc03b74003d4d,
                symbol: "dwstETH",
                tokenType: TokenType.DIESEL_LP_TOKEN
            });
            td[81] =
                TokenData({id: Tokens.dFRAX, addr: address(0), symbol: "dFRAX", tokenType: TokenType.DIESEL_LP_TOKEN});
            td[82] = TokenData({
                id: Tokens.GEAR,
                addr: 0x3321F5dA65165042903eDe71617F912942f4E70F,
                symbol: "GEAR",
                tokenType: TokenType.GEAR_TOKEN
            });
        }

        for (uint256 i = 0; i < td.length; ++i) {
            tokenData.push(td[i]);
        }
    }

    function getTokenData() external view returns (TokenData[] memory) {
        return tokenData;
    }
}
