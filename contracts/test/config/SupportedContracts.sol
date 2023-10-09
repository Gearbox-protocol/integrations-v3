// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {CheatCodes, HEVM_ADDRESS} from "@gearbox-protocol/core-v2/contracts/test/lib/cheatCodes.sol";

interface ISupportedContracts {
    function addressOf(Contracts c) external view returns (address);

    function nameOf(Contracts c) external view returns (string memory);

    function contractIndex(address) external view returns (Contracts);

    function contractCount() external view returns (uint256);
}

enum Contracts {
    NO_CONTRACT,
    UNISWAP_V2_ROUTER,
    UNISWAP_V3_ROUTER,
    SUSHISWAP_ROUTER,
    CURVE_3CRV_POOL,
    CURVE_FRAX_USDC_POOL,
    CURVE_STETH_GATEWAY,
    CURVE_FRAX_POOL,
    CURVE_LUSD_POOL,
    CURVE_SUSD_POOL,
    CURVE_SUSD_DEPOSIT,
    CURVE_GUSD_POOL,
    CURVE_MIM_POOL,
    CURVE_OHMFRAXBP_POOL,
    CURVE_CRVETH_POOL,
    CURVE_CVXETH_POOL,
    CURVE_3CRYPTO_POOL,
    CURVE_LDOETH_POOL,
    CURVE_GEAR_POOL,
    CURVE_CRVUSD_USDC_POOL,
    CURVE_CRVUSD_USDT_POOL,
    CURVE_CRVUSD_FRAX_POOL,
    CURVE_TRI_CRV_POOL,
    CURVE_RETH_ETH_POOL,
    YEARN_DAI_VAULT,
    YEARN_USDC_VAULT,
    YEARN_WETH_VAULT,
    YEARN_WBTC_VAULT,
    YEARN_CURVE_FRAX_VAULT,
    YEARN_CURVE_STETH_VAULT,
    MAKER_DSR_VAULT,
    YIELD_ETH_VAULT,
    CONVEX_BOOSTER,
    CONVEX_3CRV_POOL,
    CONVEX_FRAX_USDC_POOL,
    CONVEX_GUSD_POOL,
    CONVEX_SUSD_POOL,
    CONVEX_STECRV_POOL,
    CONVEX_FRAX3CRV_POOL,
    CONVEX_LUSD3CRV_POOL,
    CONVEX_OHMFRAXBP_POOL,
    CONVEX_MIM3CRV_POOL,
    CONVEX_CRVETH_POOL,
    CONVEX_CVXETH_POOL,
    CONVEX_3CRYPTO_POOL,
    CONVEX_LDOETH_POOL,
    CONVEX_TRI_CRV_POOL,
    AURA_BOOSTER,
    AURA_B_RETH_STABLE_POOL,
    LIDO_STETH_GATEWAY,
    LIDO_WSTETH,
    BALANCER_VAULT,
    UNIVERSAL_ADAPTER,
    AAVE_V2_LENDING_POOL,
    AAVE_V2_DAI_TOKEN_WRAPPER,
    AAVE_V2_USDC_TOKEN_WRAPPER,
    AAVE_V2_USDT_TOKEN_WRAPPER,
    AAVE_V2_WETH_TOKEN_WRAPPER,
    COMPOUND_V2_DAI_POOL,
    COMPOUND_V2_USDC_POOL,
    COMPOUND_V2_USDT_POOL,
    COMPOUND_V2_LINK_POOL,
    COMPOUND_V2_ETH_GATEWAY,
    FLUX_USDC_POOL
}

struct ContractData {
    Contracts id;
    address addr;
    string name;
}

contract SupportedContracts is ISupportedContracts {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    mapping(Contracts => address) public override addressOf;
    mapping(Contracts => string) public override nameOf;
    mapping(address => Contracts) public override contractIndex;

    uint256 public override contractCount;

    constructor(uint8 networkId) {
        if (networkId != 1) {
            revert("Network id not supported");
        }

        ContractData[] memory cd;
        cd = new  ContractData[](63);
        cd[0] = ContractData({
            id: Contracts.UNISWAP_V2_ROUTER,
            addr: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
            name: "UNISWAP_V2_ROUTER"
        });
        cd[1] = ContractData({
            id: Contracts.UNISWAP_V3_ROUTER,
            addr: 0xE592427A0AEce92De3Edee1F18E0157C05861564,
            name: "UNISWAP_V3_ROUTER"
        });
        cd[2] = ContractData({
            id: Contracts.SUSHISWAP_ROUTER,
            addr: 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F,
            name: "SUSHISWAP_ROUTER"
        });
        cd[3] = ContractData({
            id: Contracts.CURVE_3CRV_POOL,
            addr: 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7,
            name: "CURVE_3CRV_POOL"
        });
        cd[4] = ContractData({
            id: Contracts.CURVE_FRAX_USDC_POOL,
            addr: 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2,
            name: "CURVE_FRAX_USDC_POOL"
        });
        cd[5] = ContractData({
            id: Contracts.CURVE_STETH_GATEWAY,
            addr: 0xEf0D72C594b28252BF7Ea2bfbF098792430815b1,
            name: "CURVE_STETH_GATEWAY"
        });
        cd[6] = ContractData({
            id: Contracts.CURVE_FRAX_POOL,
            addr: 0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B,
            name: "CURVE_FRAX_POOL"
        });
        cd[7] = ContractData({
            id: Contracts.CURVE_LUSD_POOL,
            addr: 0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA,
            name: "CURVE_LUSD_POOL"
        });
        cd[8] = ContractData({
            id: Contracts.CURVE_SUSD_POOL,
            addr: 0xA5407eAE9Ba41422680e2e00537571bcC53efBfD,
            name: "CURVE_SUSD_POOL"
        });
        cd[9] = ContractData({
            id: Contracts.CURVE_SUSD_DEPOSIT,
            addr: 0xFCBa3E75865d2d561BE8D220616520c171F12851,
            name: "CURVE_SUSD_DEPOSIT"
        });
        cd[10] = ContractData({
            id: Contracts.CURVE_GUSD_POOL,
            addr: 0x4f062658EaAF2C1ccf8C8e36D6824CDf41167956,
            name: "CURVE_GUSD_POOL"
        });
        cd[11] = ContractData({
            id: Contracts.CURVE_MIM_POOL,
            addr: 0x5a6A4D54456819380173272A5E8E9B9904BdF41B,
            name: "CURVE_MIM_POOL"
        });
        cd[12] = ContractData({
            id: Contracts.CURVE_OHMFRAXBP_POOL,
            addr: 0xFc1e8bf3E81383Ef07Be24c3FD146745719DE48D,
            name: "CURVE_OHMFRAXBP_POOL"
        });
        cd[13] = ContractData({
            id: Contracts.CURVE_CRVETH_POOL,
            addr: 0x8301AE4fc9c624d1D396cbDAa1ed877821D7C511,
            name: "CURVE_CRVETH_POOL"
        });
        cd[14] = ContractData({
            id: Contracts.CURVE_CVXETH_POOL,
            addr: 0xB576491F1E6e5E62f1d8F26062Ee822B40B0E0d4,
            name: "CURVE_CVXETH_POOL"
        });
        cd[15] = ContractData({
            id: Contracts.CURVE_3CRYPTO_POOL,
            addr: 0xf5f5B97624542D72A9E06f04804Bf81baA15e2B4,
            name: "CURVE_3CRYPTO_POOL"
        });
        cd[16] = ContractData({
            id: Contracts.CURVE_LDOETH_POOL,
            addr: 0x9409280DC1e6D33AB7A8C6EC03e5763FB61772B5,
            name: "CURVE_LDOETH_POOL"
        });
        cd[17] = ContractData({
            id: Contracts.CURVE_GEAR_POOL,
            addr: 0x0E9B5B092caD6F1c5E6bc7f89Ffe1abb5c95F1C2,
            name: "CURVE_GEAR_POOL"
        });
        cd[18] = ContractData({
            id: Contracts.CURVE_CRVUSD_USDC_POOL,
            addr: 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E,
            name: "CURVE_CRVUSD_USDC_POOL"
        });
        cd[19] = ContractData({
            id: Contracts.CURVE_CRVUSD_USDT_POOL,
            addr: 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4,
            name: "CURVE_CRVUSD_USDT_POOL"
        });
        cd[20] = ContractData({
            id: Contracts.CURVE_CRVUSD_FRAX_POOL,
            addr: 0x0CD6f267b2086bea681E922E19D40512511BE538,
            name: "CURVE_CRVUSD_FRAX_POOL"
        });
        cd[21] = ContractData({
            id: Contracts.CURVE_TRI_CRV_POOL,
            addr: 0x4eBdF703948ddCEA3B11f675B4D1Fba9d2414A14,
            name: "CURVE_TRI_CRV_POOL"
        });
        cd[22] = ContractData({
            id: Contracts.CURVE_RETH_ETH_POOL,
            addr: 0x0f3159811670c117c372428D4E69AC32325e4D0F,
            name: "CURVE_RETH_ETH_POOL"
        });
        cd[23] = ContractData({
            id: Contracts.YEARN_DAI_VAULT,
            addr: 0xdA816459F1AB5631232FE5e97a05BBBb94970c95,
            name: "YEARN_DAI_VAULT"
        });
        cd[24] = ContractData({
            id: Contracts.YEARN_USDC_VAULT,
            addr: 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE,
            name: "YEARN_USDC_VAULT"
        });
        cd[25] = ContractData({
            id: Contracts.YEARN_WETH_VAULT,
            addr: 0xa258C4606Ca8206D8aA700cE2143D7db854D168c,
            name: "YEARN_WETH_VAULT"
        });
        cd[26] = ContractData({
            id: Contracts.YEARN_WBTC_VAULT,
            addr: 0xA696a63cc78DfFa1a63E9E50587C197387FF6C7E,
            name: "YEARN_WBTC_VAULT"
        });
        cd[27] = ContractData({
            id: Contracts.YEARN_CURVE_FRAX_VAULT,
            addr: 0xB4AdA607B9d6b2c9Ee07A275e9616B84AC560139,
            name: "YEARN_CURVE_FRAX_VAULT"
        });
        cd[28] = ContractData({
            id: Contracts.YEARN_CURVE_STETH_VAULT,
            addr: 0xdCD90C7f6324cfa40d7169ef80b12031770B4325,
            name: "YEARN_CURVE_STETH_VAULT"
        });
        cd[29] = ContractData({
            id: Contracts.MAKER_DSR_VAULT,
            addr: 0x83F20F44975D03b1b09e64809B757c47f942BEeA,
            name: "MAKER_DSR_VAULT"
        });
        cd[30] = ContractData({
            id: Contracts.YIELD_ETH_VAULT,
            addr: 0xb5b29320d2Dde5BA5BAFA1EbcD270052070483ec,
            name: "YIELD_ETH_VAULT"
        });
        cd[31] = ContractData({
            id: Contracts.CONVEX_BOOSTER,
            addr: 0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
            name: "CONVEX_BOOSTER"
        });
        cd[32] = ContractData({
            id: Contracts.CONVEX_3CRV_POOL,
            addr: 0x689440f2Ff927E1f24c72F1087E1FAF471eCe1c8,
            name: "CONVEX_3CRV_POOL"
        });
        cd[33] = ContractData({
            id: Contracts.CONVEX_FRAX_USDC_POOL,
            addr: 0x7e880867363A7e321f5d260Cade2B0Bb2F717B02,
            name: "CONVEX_FRAX_USDC_POOL"
        });
        cd[34] = ContractData({
            id: Contracts.CONVEX_GUSD_POOL,
            addr: 0x7A7bBf95C44b144979360C3300B54A7D34b44985,
            name: "CONVEX_GUSD_POOL"
        });
        cd[35] = ContractData({
            id: Contracts.CONVEX_SUSD_POOL,
            addr: 0x22eE18aca7F3Ee920D01F25dA85840D12d98E8Ca,
            name: "CONVEX_SUSD_POOL"
        });
        cd[36] = ContractData({
            id: Contracts.CONVEX_STECRV_POOL,
            addr: 0x0A760466E1B4621579a82a39CB56Dda2F4E70f03,
            name: "CONVEX_STECRV_POOL"
        });
        cd[37] = ContractData({
            id: Contracts.CONVEX_FRAX3CRV_POOL,
            addr: 0xB900EF131301B307dB5eFcbed9DBb50A3e209B2e,
            name: "CONVEX_FRAX3CRV_POOL"
        });
        cd[38] = ContractData({
            id: Contracts.CONVEX_LUSD3CRV_POOL,
            addr: 0x2ad92A7aE036a038ff02B96c88de868ddf3f8190,
            name: "CONVEX_LUSD3CRV_POOL"
        });
        cd[39] = ContractData({
            id: Contracts.CONVEX_OHMFRAXBP_POOL,
            addr: 0x27A8c58e3DE84280826d615D80ddb33930383fE9,
            name: "CONVEX_OHMFRAXBP_POOL"
        });
        cd[40] = ContractData({
            id: Contracts.CONVEX_MIM3CRV_POOL,
            addr: 0xFd5AbF66b003881b88567EB9Ed9c651F14Dc4771,
            name: "CONVEX_MIM3CRV_POOL"
        });
        cd[41] = ContractData({
            id: Contracts.CONVEX_CRVETH_POOL,
            addr: 0x085A2054c51eA5c91dbF7f90d65e728c0f2A270f,
            name: "CONVEX_CRVETH_POOL"
        });
        cd[42] = ContractData({
            id: Contracts.CONVEX_CVXETH_POOL,
            addr: 0xb1Fb0BA0676A1fFA83882c7F4805408bA232C1fA,
            name: "CONVEX_CVXETH_POOL"
        });
        cd[43] = ContractData({
            id: Contracts.CONVEX_3CRYPTO_POOL,
            addr: 0xb05262D4aaAA38D0Af4AaB244D446ebDb5afd4A7,
            name: "CONVEX_3CRYPTO_POOL"
        });
        cd[44] = ContractData({
            id: Contracts.CONVEX_LDOETH_POOL,
            addr: 0x8CA990E954611E5E3d2cc51C013fCC372c8c1D38,
            name: "CONVEX_LDOETH_POOL"
        });
        cd[45] = ContractData({
            id: Contracts.CONVEX_TRI_CRV_POOL,
            addr: 0xF956a46DbA1A0a567168db8655bc18E9050C7738,
            name: "CONVEX_TRI_CRV_POOL"
        });
        cd[46] = ContractData({
            id: Contracts.AURA_BOOSTER,
            addr: 0xA57b8d98dAE62B26Ec3bcC4a365338157060B234,
            name: "AURA_BOOSTER"
        });
        cd[47] = ContractData({
            id: Contracts.AURA_B_RETH_STABLE_POOL,
            addr: 0x9497df26e5bD669Cb925eC68E730492b9300c482,
            name: "AURA_B_RETH_STABLE_POOL"
        });
        cd[48] = ContractData({
            id: Contracts.LIDO_STETH_GATEWAY,
            addr: 0x6f4b4aB5142787c05b7aB9A9692A0f46b997C29D,
            name: "LIDO_STETH_GATEWAY"
        });
        cd[49] = ContractData({
            id: Contracts.LIDO_WSTETH,
            addr: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
            name: "LIDO_WSTETH"
        });
        cd[50] = ContractData({
            id: Contracts.BALANCER_VAULT,
            addr: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            name: "BALANCER_VAULT"
        });
        cd[51] = ContractData({
            id: Contracts.UNIVERSAL_ADAPTER,
            addr: 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC,
            name: "UNIVERSAL_ADAPTER"
        });
        cd[52] = ContractData({
            id: Contracts.AAVE_V2_LENDING_POOL,
            addr: 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9,
            name: "AAVE_V2_LENDING_POOL"
        });
        cd[53] =
            ContractData({id: Contracts.AAVE_V2_DAI_TOKEN_WRAPPER, addr: address(0), name: "AAVE_V2_DAI_TOKEN_WRAPPER"});
        cd[54] = ContractData({
            id: Contracts.AAVE_V2_USDC_TOKEN_WRAPPER,
            addr: address(0),
            name: "AAVE_V2_USDC_TOKEN_WRAPPER"
        });
        cd[55] = ContractData({
            id: Contracts.AAVE_V2_USDT_TOKEN_WRAPPER,
            addr: address(0),
            name: "AAVE_V2_USDT_TOKEN_WRAPPER"
        });
        cd[56] = ContractData({
            id: Contracts.AAVE_V2_WETH_TOKEN_WRAPPER,
            addr: address(0),
            name: "AAVE_V2_WETH_TOKEN_WRAPPER"
        });
        cd[57] = ContractData({
            id: Contracts.COMPOUND_V2_DAI_POOL,
            addr: 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643,
            name: "COMPOUND_V2_DAI_POOL"
        });
        cd[58] = ContractData({
            id: Contracts.COMPOUND_V2_USDC_POOL,
            addr: 0x39AA39c021dfbaE8faC545936693aC917d5E7563,
            name: "COMPOUND_V2_USDC_POOL"
        });
        cd[59] = ContractData({
            id: Contracts.COMPOUND_V2_USDT_POOL,
            addr: 0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9,
            name: "COMPOUND_V2_USDT_POOL"
        });
        cd[60] = ContractData({
            id: Contracts.COMPOUND_V2_LINK_POOL,
            addr: 0xFAce851a4921ce59e912d19329929CE6da6EB0c7,
            name: "COMPOUND_V2_LINK_POOL"
        });
        cd[61] =
            ContractData({id: Contracts.COMPOUND_V2_ETH_GATEWAY, addr: address(0), name: "COMPOUND_V2_ETH_GATEWAY"});
        cd[62] = ContractData({
            id: Contracts.FLUX_USDC_POOL,
            addr: 0x465a5a630482f3abD6d3b84B39B29b07214d19e5,
            name: "FLUX_USDC_POOL"
        });

        uint256 len = cd.length;
        contractCount = len;
        unchecked {
            for (uint256 i; i < len; ++i) {
                addressOf[cd[i].id] = cd[i].addr;
                nameOf[cd[i].id] = cd[i].name;
                contractIndex[cd[i].addr] = cd[i].id;

                evm.label(cd[i].addr, cd[i].name);
            }
        }
    }
}
