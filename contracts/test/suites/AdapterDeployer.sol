// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

// CONFIG
import { Tokens } from "../config/Tokens.sol";
import { Contracts } from "../config/SupportedContracts.sol";
import { AdapterData } from "../config/AdapterData.sol";
import { SupportedContracts } from "../config/SupportedContracts.sol";

import { Adapter } from "@gearbox-protocol/core-v2/contracts/factories/CreditManagerFactoryBase.sol";

import { AdapterType } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

import "@gearbox-protocol/core-v2/contracts/test/lib/test.sol";
import { CheatCodes, HEVM_ADDRESS } from "@gearbox-protocol/core-v2/contracts/test/lib/cheatCodes.sol";

// SIMPLE ADAPTERS
import { UniswapV2Adapter } from "../../adapters/uniswap/UniswapV2.sol";
import { UniswapV3Adapter } from "../../adapters/uniswap/UniswapV3.sol";
import { YearnV2Adapter } from "../../adapters/yearn/YearnV2.sol";
import { ConvexV1BoosterAdapter } from "../../adapters/convex/ConvexV1_Booster.sol";
import { ConvexV1ClaimZapAdapter } from "../../adapters/convex/ConvexV1_ClaimZap.sol";
import { LidoV1Adapter } from "../../adapters/lido/LidoV1.sol";
import { WstETHV1Adapter } from "../../adapters/lido/WstETHV1.sol";

import { UniversalAdapter } from "@gearbox-protocol/core-v2/contracts/adapters/UniversalAdapter.sol";

import { CurveV1Adapter2Assets } from "../../adapters/curve/CurveV1_2.sol";
import { CurveV1Adapter3Assets } from "../../adapters/curve/CurveV1_3.sol";
import { CurveV1Adapter4Assets } from "../../adapters/curve/CurveV1_4.sol";

import { CurveV1AdapterStETH } from "../../adapters/curve/CurveV1_stETH.sol";
import { CurveV1AdapterDeposit } from "../../adapters/curve/CurveV1_DepositZap.sol";

import { ConvexV1BaseRewardPoolAdapter } from "../../adapters/convex/ConvexV1_BaseRewardPool.sol";

import { TokensTestSuite } from "./TokensTestSuite.sol";

// CURVE ADAPTERS

contract AdapterDeployer is AdapterData, DSTest {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);
    Adapter[] public adapters;
    TokensTestSuite tokenTestSuite;
    SupportedContracts supportedContracts;
    error AdapterNotFoundException(Contracts);

    address uniswapPathChecker;

    constructor(
        address creditManager,
        Contracts[] memory adaptersList,
        TokensTestSuite _tokenTestSuite,
        SupportedContracts _supportedContracts,
        string memory cmLabel
    ) AdapterData() {
        tokenTestSuite = _tokenTestSuite;
        supportedContracts = _supportedContracts;
        uint256 len = adaptersList.length;

        unchecked {
            for (uint256 i; i < len; ++i) {
                Adapter memory newAdapter = deployAdapter(
                    creditManager,
                    adaptersList[i]
                );

                adapters.push(newAdapter);
                evm.label(
                    newAdapter.adapter,
                    string(
                        abi.encodePacked(
                            cmLabel,
                            "_ADAPTER_",
                            supportedContracts.nameOf(adaptersList[i])
                        )
                    )
                );
            }
        }
    }

    function _getInitConnectors()
        internal
        view
        returns (address[] memory connectors)
    {
        connectors = new address[](4);

        connectors[0] = tokenTestSuite.addressOf(Tokens.DAI);
        connectors[1] = tokenTestSuite.addressOf(Tokens.USDC);
        connectors[2] = tokenTestSuite.addressOf(Tokens.WETH);
        connectors[3] = tokenTestSuite.addressOf(Tokens.FRAX);
    }

    function getAdapters() external view returns (Adapter[] memory) {
        return adapters;
    }

    function deployAdapter(address creditManager, Contracts cnt)
        internal
        returns (Adapter memory result)
    {
        uint256 len = simpleAdapters.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                if (cnt == simpleAdapters[i].targetContract) {
                    AdapterType at = simpleAdapters[i].adapterType;
                    result.targetContract = supportedContracts.addressOf(cnt);

                    if (at == AdapterType.UNISWAP_V2_ROUTER) {
                        result.adapter = address(
                            new UniswapV2Adapter(
                                creditManager,
                                result.targetContract,
                                _getInitConnectors()
                            )
                        );
                    } else if (at == AdapterType.UNISWAP_V3_ROUTER) {
                        result.adapter = address(
                            new UniswapV3Adapter(
                                creditManager,
                                result.targetContract,
                                _getInitConnectors()
                            )
                        );
                    }
                    if (at == AdapterType.YEARN_V2) {
                        result.adapter = address(
                            new YearnV2Adapter(
                                creditManager,
                                result.targetContract
                            )
                        );
                    } else if (at == AdapterType.CONVEX_V1_BOOSTER) {
                        result.adapter = address(
                            new ConvexV1BoosterAdapter(
                                creditManager,
                                result.targetContract
                            )
                        );
                    } else if (at == AdapterType.CONVEX_V1_CLAIM_ZAP) {
                        result.adapter = address(
                            new ConvexV1ClaimZapAdapter(
                                creditManager,
                                result.targetContract
                            )
                        );
                    } else if (at == AdapterType.LIDO_V1) {
                        result.adapter = address(
                            new LidoV1Adapter(
                                creditManager,
                                result.targetContract
                            )
                        );
                        result.targetContract = LidoV1Adapter(result.adapter)
                            .targetContract();
                    } else if (at == AdapterType.UNIVERSAL) {
                        result.adapter = address(
                            new UniversalAdapter(creditManager)
                        );
                    } else if (at == AdapterType.LIDO_WSTETH_V1) {
                        result.adapter = address(
                            new WstETHV1Adapter(
                                creditManager,
                                tokenTestSuite.addressOf(Tokens.wstETH)
                            )
                        );
                    }

                    return result;
                }
            }

            len = curveAdapters.length;
            for (uint256 i; i < len; ++i) {
                if (cnt == curveAdapters[i].targetContract) {
                    AdapterType at = curveAdapters[i].adapterType;
                    result.targetContract = supportedContracts.addressOf(cnt);

                    if (at == AdapterType.CURVE_V1_2ASSETS) {
                        result.adapter = address(
                            new CurveV1Adapter2Assets(
                                creditManager,
                                result.targetContract,
                                tokenTestSuite.addressOf(
                                    curveAdapters[i].lpToken
                                ),
                                supportedContracts.addressOf(
                                    curveAdapters[i].basePool
                                )
                            )
                        );
                    } else if (at == AdapterType.CURVE_V1_3ASSETS) {
                        result.adapter = address(
                            new CurveV1Adapter3Assets(
                                creditManager,
                                result.targetContract,
                                tokenTestSuite.addressOf(
                                    curveAdapters[i].lpToken
                                ),
                                address(0)
                            )
                        );
                    } else if (at == AdapterType.CURVE_V1_4ASSETS) {
                        result.adapter = address(
                            new CurveV1Adapter4Assets(
                                creditManager,
                                result.targetContract,
                                tokenTestSuite.addressOf(
                                    curveAdapters[i].lpToken
                                ),
                                address(0)
                            )
                        );
                    }
                    return result;
                }
            }

            if (cnt == curveStEthAdapter.curveETHGateway) {
                result.targetContract = supportedContracts.addressOf(cnt);
                result.adapter = address(
                    new CurveV1AdapterStETH(
                        creditManager,
                        supportedContracts.addressOf(
                            curveStEthAdapter.curveETHGateway
                        ),
                        tokenTestSuite.addressOf(curveStEthAdapter.lpToken)
                    )
                );
                return result;
            }

            len = curveWrappers.length;
            for (uint256 i; i < len; ++i) {
                if (cnt == curveWrappers[i].targetContract) {
                    result.targetContract = supportedContracts.addressOf(cnt);
                    result.adapter = address(
                        new CurveV1AdapterDeposit(
                            creditManager,
                            result.targetContract,
                            tokenTestSuite.addressOf(curveWrappers[i].lpToken),
                            curveWrappers[i].nCoins
                        )
                    );
                    return result;
                }
            }

            len = convexBasePoolAdapters.length;
            for (uint256 i; i < len; ++i) {
                if (cnt == convexBasePoolAdapters[i].targetContract) {
                    result.targetContract = supportedContracts.addressOf(cnt);
                    result.adapter = address(
                        new ConvexV1BaseRewardPoolAdapter(
                            creditManager,
                            result.targetContract,
                            tokenTestSuite.addressOf(
                                convexBasePoolAdapters[i].stakedToken
                            )
                        )
                    );
                    return result;
                }
            }

            revert AdapterNotFoundException(cnt);
        }
    }
}
