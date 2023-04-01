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
    CURVE_GEAR_POOL,
    YEARN_DAI_VAULT,
    YEARN_USDC_VAULT,
    YEARN_WETH_VAULT,
    YEARN_WBTC_VAULT,
    YEARN_CURVE_FRAX_VAULT,
    YEARN_CURVE_STETH_VAULT,
    CONVEX_BOOSTER,
    CONVEX_3CRV_POOL,
    CONVEX_FRAX_USDC_POOL,
    CONVEX_GUSD_POOL,
    CONVEX_SUSD_POOL,
    CONVEX_STECRV_POOL,
    CONVEX_FRAX3CRV_POOL,
    CONVEX_LUSD3CRV_POOL,
    LIDO_STETH_GATEWAY,
    LIDO_WSTETH,
    UNIVERSAL_ADAPTER
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
        ContractData[] memory cd;
        if (networkId == 1) {
            cd = new  ContractData[](29);
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
                id: Contracts.CURVE_GEAR_POOL,
                addr: 0x0E9B5B092caD6F1c5E6bc7f89Ffe1abb5c95F1C2,
                name: "CURVE_GEAR_POOL"
            });
            cd[12] = ContractData({
                id: Contracts.YEARN_DAI_VAULT,
                addr: 0xdA816459F1AB5631232FE5e97a05BBBb94970c95,
                name: "YEARN_DAI_VAULT"
            });
            cd[13] = ContractData({
                id: Contracts.YEARN_USDC_VAULT,
                addr: 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE,
                name: "YEARN_USDC_VAULT"
            });
            cd[14] = ContractData({
                id: Contracts.YEARN_WETH_VAULT,
                addr: 0xa258C4606Ca8206D8aA700cE2143D7db854D168c,
                name: "YEARN_WETH_VAULT"
            });
            cd[15] = ContractData({
                id: Contracts.YEARN_WBTC_VAULT,
                addr: 0xA696a63cc78DfFa1a63E9E50587C197387FF6C7E,
                name: "YEARN_WBTC_VAULT"
            });
            cd[16] = ContractData({
                id: Contracts.YEARN_CURVE_FRAX_VAULT,
                addr: 0xB4AdA607B9d6b2c9Ee07A275e9616B84AC560139,
                name: "YEARN_CURVE_FRAX_VAULT"
            });
            cd[17] = ContractData({
                id: Contracts.YEARN_CURVE_STETH_VAULT,
                addr: 0xdCD90C7f6324cfa40d7169ef80b12031770B4325,
                name: "YEARN_CURVE_STETH_VAULT"
            });
            cd[18] = ContractData({
                id: Contracts.CONVEX_BOOSTER,
                addr: 0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                name: "CONVEX_BOOSTER"
            });
            cd[19] = ContractData({
                id: Contracts.CONVEX_3CRV_POOL,
                addr: 0x689440f2Ff927E1f24c72F1087E1FAF471eCe1c8,
                name: "CONVEX_3CRV_POOL"
            });
            cd[20] = ContractData({
                id: Contracts.CONVEX_FRAX_USDC_POOL,
                addr: 0x7e880867363A7e321f5d260Cade2B0Bb2F717B02,
                name: "CONVEX_FRAX_USDC_POOL"
            });
            cd[21] = ContractData({
                id: Contracts.CONVEX_GUSD_POOL,
                addr: 0x7A7bBf95C44b144979360C3300B54A7D34b44985,
                name: "CONVEX_GUSD_POOL"
            });
            cd[22] = ContractData({
                id: Contracts.CONVEX_SUSD_POOL,
                addr: 0x22eE18aca7F3Ee920D01F25dA85840D12d98E8Ca,
                name: "CONVEX_SUSD_POOL"
            });
            cd[23] = ContractData({
                id: Contracts.CONVEX_STECRV_POOL,
                addr: 0x0A760466E1B4621579a82a39CB56Dda2F4E70f03,
                name: "CONVEX_STECRV_POOL"
            });
            cd[24] = ContractData({
                id: Contracts.CONVEX_FRAX3CRV_POOL,
                addr: 0xB900EF131301B307dB5eFcbed9DBb50A3e209B2e,
                name: "CONVEX_FRAX3CRV_POOL"
            });
            cd[25] = ContractData({
                id: Contracts.CONVEX_LUSD3CRV_POOL,
                addr: 0x2ad92A7aE036a038ff02B96c88de868ddf3f8190,
                name: "CONVEX_LUSD3CRV_POOL"
            });
            cd[26] = ContractData({
                id: Contracts.LIDO_STETH_GATEWAY,
                addr: 0x6f4b4aB5142787c05b7aB9A9692A0f46b997C29D,
                name: "LIDO_STETH_GATEWAY"
            });
            cd[27] = ContractData({
                id: Contracts.LIDO_WSTETH,
                addr: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
                name: "LIDO_WSTETH"
            });
            cd[28] = ContractData({
                id: Contracts.UNIVERSAL_ADAPTER,
                addr: 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC,
                name: "UNIVERSAL_ADAPTER"
            });
        } else if (networkId == 2) {
            cd = new  ContractData[](30);
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
                addr: 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506,
                name: "SUSHISWAP_ROUTER"
            });
            cd[3] = ContractData({
                id: Contracts.CURVE_3CRV_POOL,
                addr: 0x6491f8A62678c90C84b237791d9D7cF21b4D1418,
                name: "CURVE_3CRV_POOL"
            });
            cd[4] = ContractData({
                id: Contracts.CURVE_FRAX_USDC_POOL,
                addr: 0x9C85E4F4061160B6177cad3f72EDfd374Dc8AD88,
                name: "CURVE_FRAX_USDC_POOL"
            });
            cd[5] = ContractData({
                id: Contracts.CURVE_STETH_GATEWAY,
                addr: 0x6019fEa75c460ef205ef4C626F196055BAD89D1E,
                name: "CURVE_STETH_GATEWAY"
            });
            cd[6] = ContractData({
                id: Contracts.CURVE_FRAX_POOL,
                addr: 0x12Ad3125C67eC5325Cc94AFdA8B26cd12BCe1E9b,
                name: "CURVE_FRAX_POOL"
            });
            cd[7] = ContractData({
                id: Contracts.CURVE_LUSD_POOL,
                addr: 0x348B1846b87cA12D23A9A4E73B1CfAc2Aad49cf4,
                name: "CURVE_LUSD_POOL"
            });
            cd[8] = ContractData({
                id: Contracts.CURVE_SUSD_POOL,
                addr: 0x2A1b874C86734feA5be050d32fAb02FCF9eB1Bc2,
                name: "CURVE_SUSD_POOL"
            });
            cd[9] = ContractData({
                id: Contracts.CURVE_SUSD_DEPOSIT,
                addr: 0x9782f1fF1AEFb387F01cae72F668F13E8061d9Dd,
                name: "CURVE_SUSD_DEPOSIT"
            });
            cd[10] = ContractData({
                id: Contracts.CURVE_GUSD_POOL,
                addr: 0x8C954d89C2fB2c96F0195738b8c5538B34D5344E,
                name: "CURVE_GUSD_POOL"
            });
            cd[12] = ContractData({
                id: Contracts.YEARN_DAI_VAULT,
                addr: 0xAAC67551F8d1D052E375BaCf774b494850BBca87,
                name: "YEARN_DAI_VAULT"
            });
            cd[13] = ContractData({
                id: Contracts.YEARN_USDC_VAULT,
                addr: 0x05724F02a0270F08E525F2681afA9173957c505e,
                name: "YEARN_USDC_VAULT"
            });
            cd[14] = ContractData({
                id: Contracts.YEARN_WETH_VAULT,
                addr: 0xEe8Adf657c5EF8e10622b6B47014D2C6f6993E5E,
                name: "YEARN_WETH_VAULT"
            });
            cd[15] = ContractData({
                id: Contracts.YEARN_WBTC_VAULT,
                addr: 0x683fcBf347b90C652b4B07648180C0b54c258815,
                name: "YEARN_WBTC_VAULT"
            });
            cd[16] = ContractData({
                id: Contracts.YEARN_CURVE_FRAX_VAULT,
                addr: 0x43d45AEf2BAb5fa79e3bBDb2dB7E4443B8123C8f,
                name: "YEARN_CURVE_FRAX_VAULT"
            });
            cd[17] = ContractData({
                id: Contracts.YEARN_CURVE_STETH_VAULT,
                addr: 0x2681AFa48aCFC2Ae5308bf6127d2fb563763f13E,
                name: "YEARN_CURVE_STETH_VAULT"
            });
            cd[18] = ContractData({
                id: Contracts.CONVEX_BOOSTER,
                addr: 0xbd1D47bbF57F49D9a72ca7f879A096d3abDF4c40,
                name: "CONVEX_BOOSTER"
            });
            cd[19] = ContractData({
                id: Contracts.CONVEX_3CRV_POOL,
                addr: 0xfB9b98558c3d6851291Fbf74fa7F022a787cD795,
                name: "CONVEX_3CRV_POOL"
            });
            cd[20] = ContractData({
                id: Contracts.CONVEX_FRAX_USDC_POOL,
                addr: 0xAc22d4495166c945cc91FDB611b7515eBbfd60c0,
                name: "CONVEX_FRAX_USDC_POOL"
            });
            cd[21] = ContractData({
                id: Contracts.CONVEX_GUSD_POOL,
                addr: 0xa8eD353f56BB2e1063B8a011F0491a1703998De4,
                name: "CONVEX_GUSD_POOL"
            });
            cd[22] = ContractData({
                id: Contracts.CONVEX_SUSD_POOL,
                addr: 0x85825316be95FBb3F6B5a2Dd9f1eb9577803e441,
                name: "CONVEX_SUSD_POOL"
            });
            cd[23] = ContractData({
                id: Contracts.CONVEX_STECRV_POOL,
                addr: 0xd9de8eA4289e7a4458Bebad8c31bb7576f1C2B72,
                name: "CONVEX_STECRV_POOL"
            });
            cd[24] = ContractData({
                id: Contracts.CONVEX_FRAX3CRV_POOL,
                addr: 0x08513eA45fdd7A9cFC33702f722090a182e4a101,
                name: "CONVEX_FRAX3CRV_POOL"
            });
            cd[25] = ContractData({
                id: Contracts.CONVEX_LUSD3CRV_POOL,
                addr: 0x8550134faa6Cb42a7668f3D9098EBa59FA959b40,
                name: "CONVEX_LUSD3CRV_POOL"
            });
            cd[26] = ContractData({
                id: Contracts.LIDO_STETH_GATEWAY,
                addr: 0x9290E44f5f819b7de0Fb88b10641f9F08a999BF7,
                name: "LIDO_STETH_GATEWAY"
            });
            cd[27] = ContractData({
                id: Contracts.LIDO_WSTETH,
                addr: 0x5E590e6c887A84098F3fa465267a44AaE058eBbb,
                name: "LIDO_WSTETH"
            });
            cd[28] = ContractData({
                id: Contracts.UNIVERSAL_ADAPTER,
                addr: 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC,
                name: "UNIVERSAL_ADAPTER"
            });
        }
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
