// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.10;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditConfiguratorV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditConfiguratorV3.sol";
// CONFIG
import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {AdapterData} from "@gearbox-protocol/sdk-gov/contracts/AdapterData.sol";
import {SupportedContracts, Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

// SIMPLE ADAPTERS
import {UniswapV2Adapter} from "../../adapters/uniswap/UniswapV2.sol";
import {UniswapV3Adapter} from "../../adapters/uniswap/UniswapV3.sol";
import {YearnV2Adapter} from "../../adapters/yearn/YearnV2.sol";
import {ConvexV1BoosterAdapter} from "../../adapters/convex/ConvexV1_Booster.sol";
import {LidoV1Adapter} from "../../adapters/lido/LidoV1.sol";
import {WstETHV1Adapter} from "../../adapters/lido/WstETHV1.sol";

import {CurveV1Adapter2Assets} from "../../adapters/curve/CurveV1_2.sol";
import {CurveV1Adapter3Assets} from "../../adapters/curve/CurveV1_3.sol";
import {CurveV1Adapter4Assets} from "../../adapters/curve/CurveV1_4.sol";

import {CurveV1AdapterStETH} from "../../adapters/curve/CurveV1_stETH.sol";
import {CurveV1AdapterDeposit} from "../../adapters/curve/CurveV1_DepositZap.sol";

import {ConvexV1BaseRewardPoolAdapter} from "../../adapters/convex/ConvexV1_BaseRewardPool.sol";

import {CompoundV2_CErc20Adapter} from "../../adapters/compound/CompoundV2_CErc20Adapter.sol";
import {CompoundV2_CEtherAdapter} from "../../adapters/compound/CompoundV2_CEtherAdapter.sol";

import {AaveV2_LendingPoolAdapter} from "../../adapters/aave/AaveV2_LendingPoolAdapter.sol";
import {AaveV2_WrappedATokenAdapter} from "../../adapters/aave/AaveV2_WrappedATokenAdapter.sol";

import {ERC4626Adapter} from "../../adapters/erc4626/ERC4626Adapter.sol";

import {BalancerV2VaultAdapter} from "../../adapters/balancer/BalancerV2VaultAdapter.sol";
import {VelodromeV2RouterAdapter} from "../../adapters/velodrome/VelodromeV2RouterAdapter.sol";

import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";
import {Test} from "forge-std/Test.sol";

import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

contract AdapterDeployer is AdapterData, Test {
    ICreditManagerV3 public creditManager;
    address[] public adapters;
    TokensTestSuite tokenTestSuite;
    SupportedContracts supportedContracts;

    error AdapterNotFoundException(Contracts);

    address uniswapPathChecker;

    constructor(
        address _creditManager,
        Contracts[] memory adaptersList,
        TokensTestSuite _tokenTestSuite,
        SupportedContracts _supportedContracts
    ) AdapterData() {
        tokenTestSuite = _tokenTestSuite;
        supportedContracts = _supportedContracts;
        creditManager = ICreditManagerV3(_creditManager);

        uint256 len = adaptersList.length;

        string memory cmLabel = string.concat("CreditManager ", ERC20(creditManager.underlying()).symbol());

        unchecked {
            for (uint256 i; i < len; ++i) {
                address newAdapter = deployAdapter(adaptersList[i]);

                adapters.push(newAdapter);
                vm.label(
                    newAdapter,
                    string(abi.encodePacked(cmLabel, "_ADAPTER_", supportedContracts.nameOf(adaptersList[i])))
                );
            }
        }
    }

    function _isCollateralToken(address token) internal view returns (bool) {
        try creditManager.getTokenMaskOrRevert(token) returns (uint256) {
            return true;
        } catch {
            return false;
        }
    }

    function getAdapters() external view returns (address[] memory) {
        return adapters;
    }

    function deployAdapter(Contracts cnt) internal returns (address adapter) {
        uint256 len = simpleAdapters.length;
        address targetContract;
        unchecked {
            for (uint256 i; i < len; ++i) {
                if (cnt == simpleAdapters[i].targetContract) {
                    AdapterType at = simpleAdapters[i].adapterType;
                    targetContract = supportedContracts.addressOf(cnt);

                    if (at == AdapterType.UNISWAP_V2_ROUTER) {
                        adapter = address(new UniswapV2Adapter(address(creditManager), targetContract));
                    } else if (at == AdapterType.UNISWAP_V3_ROUTER) {
                        adapter = address(new UniswapV3Adapter(address(creditManager), targetContract));
                    }
                    if (at == AdapterType.YEARN_V2) {
                        adapter = address(new YearnV2Adapter(address(creditManager), targetContract));
                    } else if (at == AdapterType.CONVEX_V1_BOOSTER) {
                        adapter = address(new ConvexV1BoosterAdapter(address(creditManager), targetContract));
                    } else if (at == AdapterType.LIDO_V1) {
                        adapter = address(new LidoV1Adapter(address(creditManager), targetContract));
                        targetContract = LidoV1Adapter(adapter).targetContract();
                    } else if (at == AdapterType.LIDO_WSTETH_V1) {
                        adapter = address(
                            new WstETHV1Adapter(address(creditManager), tokenTestSuite.addressOf(Tokens.wstETH))
                        );
                    } else if (at == AdapterType.COMPOUND_V2_CERC20) {
                        adapter = address(new CompoundV2_CErc20Adapter(address(creditManager), targetContract));
                    } else if (at == AdapterType.COMPOUND_V2_CETHER) {
                        adapter = address(new CompoundV2_CEtherAdapter(address(creditManager), targetContract));
                    } else if (at == AdapterType.AAVE_V2_LENDING_POOL) {
                        adapter = address(new AaveV2_LendingPoolAdapter(address(creditManager), targetContract));
                    } else if (at == AdapterType.AAVE_V2_WRAPPED_ATOKEN) {
                        adapter = address(new AaveV2_WrappedATokenAdapter(address(creditManager), targetContract));
                    } else if (at == AdapterType.ERC4626_VAULT) {
                        adapter = address(new ERC4626Adapter(address(creditManager), targetContract));
                    } else if (at == AdapterType.BALANCER_VAULT) {
                        adapter = address(new BalancerV2VaultAdapter(address(creditManager), targetContract));
                    } else if (at == AdapterType.VELODROME_V2_ROUTER) {
                        adapter = address(new VelodromeV2RouterAdapter(address(creditManager), targetContract));
                    }

                    return adapter;
                }
            }

            len = curveAdapters.length;
            for (uint256 i; i < len; ++i) {
                if (cnt == curveAdapters[i].targetContract) {
                    AdapterType at = curveAdapters[i].adapterType;
                    targetContract = supportedContracts.addressOf(cnt);

                    if (at == AdapterType.CURVE_V1_2ASSETS) {
                        adapter = address(
                            new CurveV1Adapter2Assets(
                                address(creditManager),
                                targetContract,
                                tokenTestSuite.addressOf(curveAdapters[i].lpToken),
                                supportedContracts.addressOf(curveAdapters[i].basePool)
                            )
                        );
                    } else if (at == AdapterType.CURVE_V1_3ASSETS) {
                        adapter = address(
                            new CurveV1Adapter3Assets(
                                address(creditManager),
                                targetContract,
                                tokenTestSuite.addressOf(curveAdapters[i].lpToken),
                                address(0)
                            )
                        );
                    } else if (at == AdapterType.CURVE_V1_4ASSETS) {
                        adapter = address(
                            new CurveV1Adapter4Assets(
                                address(creditManager),
                                targetContract,
                                tokenTestSuite.addressOf(curveAdapters[i].lpToken),
                                address(0)
                            )
                        );
                    }
                    return adapter;
                }
            }

            len = curveStEthAdapters.length;
            for (uint256 i; i < len; ++i) {
                if (cnt == curveStEthAdapters[i].curveETHGateway) {
                    targetContract = supportedContracts.addressOf(cnt);
                    adapter = address(
                        new CurveV1AdapterStETH(
                            address(creditManager),
                            supportedContracts.addressOf(curveStEthAdapters[i].curveETHGateway),
                            tokenTestSuite.addressOf(curveStEthAdapters[i].lpToken)
                        )
                    );
                    return adapter;
                }
            }

            len = curveWrappers.length;
            for (uint256 i; i < len; ++i) {
                if (cnt == curveWrappers[i].targetContract) {
                    targetContract = supportedContracts.addressOf(cnt);
                    adapter = address(
                        new CurveV1AdapterDeposit(
                            address(creditManager),
                            targetContract,
                            tokenTestSuite.addressOf(curveWrappers[i].lpToken),
                            curveWrappers[i].nCoins
                        )
                    );
                    return adapter;
                }
            }

            len = convexBasePoolAdapters.length;
            for (uint256 i; i < len; ++i) {
                if (cnt == convexBasePoolAdapters[i].targetContract) {
                    targetContract = supportedContracts.addressOf(cnt);
                    adapter = address(
                        new ConvexV1BaseRewardPoolAdapter(
                            address(creditManager),
                            targetContract,
                            tokenTestSuite.addressOf(convexBasePoolAdapters[i].stakedToken)
                        )
                    );
                    return adapter;
                }
            }

            revert AdapterNotFoundException(cnt);
        }
    }

    function connectAdapters() external {
        ICreditConfiguratorV3 creditConfigurator = ICreditConfiguratorV3(creditManager.creditConfigurator());
        uint256 len = adapters.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                vm.prank(CONFIGURATOR);
                creditConfigurator.allowAdapter(adapters[i]);
            }
        }
    }
}
