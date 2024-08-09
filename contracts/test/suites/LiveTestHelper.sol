// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.10;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {DegenNFTMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/DegenNFTMock.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {SupportedContracts, Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";
import {
    IPoolV3DeployConfig,
    CreditManagerV3DeployParams,
    BalancerPool,
    UniswapV3Pair,
    GenericSwapPair,
    VelodromeV2Pool
} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";

import {PriceFeedDeployer} from "@gearbox-protocol/oracles-v3/contracts/test/suites/PriceFeedDeployer.sol";
import {IntegrationTestHelper} from "@gearbox-protocol/core-v3/contracts/test/helpers/IntegrationTestHelper.sol";
import {AdapterDeployer} from "./AdapterDeployer.sol";

import {CONFIG_MAINNET_USDC_V3} from "../config/USDC_Mainnet_config.sol";
import {CONFIG_MAINNET_WBTC_V3} from "../config/WBTC_Mainnet_config.sol";
import {CONFIG_MAINNET_WETH_V3} from "../config/WETH_Mainnet_config.sol";
import {CONFIG_MAINNET_GHO_V3} from "../config/GHO_Mainnet_config.sol";
import {CONFIG_MAINNET_DAI_V3} from "../config/DAI_Mainnet_config.sol";
import {CONFIG_MAINNET_USDT_V3} from "../config/USDT_Mainnet_config.sol";
import {CONFIG_MAINNET_CRVUSD_V3} from "../config/CRVUSD_Mainnet_config.sol";

import {CONFIG_OPTIMISM_USDC_V3} from "../config/USDC_Optimism_config.sol";
import {CONFIG_OPTIMISM_WETH_V3} from "../config/WETH_Optimism_config.sol";

import {CONFIG_ARBITRUM_USDC_V3} from "../config/USDC_Arbitrum_config.sol";
import {CONFIG_ARBITRUM_USDCE_V3} from "../config/USDCE_Arbitrum_config.sol";
import {CONFIG_ARBITRUM_WETH_V3} from "../config/WETH_Arbitrum_config.sol";

import {CONFIG_MAINNET_USDC_TEST_V3} from "../config/TEST_USDC_Mainnet_config.sol";
import {CONFIG_ARBITRUM_WETH_TEST_V3} from "../config/TEST_WETH_Arbitrum_config.sol";

import {IConvexV1BoosterAdapter} from "../../interfaces/convex/IConvexV1BoosterAdapter.sol";
import {BalancerV2VaultAdapter} from "../../adapters/balancer/BalancerV2VaultAdapter.sol";
import {UniswapV2Adapter} from "../../adapters/uniswap/UniswapV2.sol";
import {UniswapV3Adapter} from "../../adapters/uniswap/UniswapV3.sol";
import {ZircuitPoolAdapter} from "../../adapters/zircuit/ZircuitPoolAdapter.sol";
import {VelodromeV2RouterAdapter} from "../../adapters/velodrome/VelodromeV2RouterAdapter.sol";
import {CamelotV3Adapter} from "../../adapters/camelot/CamelotV3Adapter.sol";
import {PoolStatus} from "../../interfaces/balancer/IBalancerV2VaultAdapter.sol";
import {UniswapV2PairStatus} from "../../interfaces/uniswap/IUniswapV2Adapter.sol";
import {UniswapV3PoolStatus} from "../../interfaces/uniswap/IUniswapV3Adapter.sol";
import {VelodromeV2PoolStatus} from "../../interfaces/velodrome/IVelodromeV2RouterAdapter.sol";
import {CamelotV3PoolStatus} from "../../interfaces/camelot/ICamelotV3Adapter.sol";

import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

import "forge-std/console.sol";

contract LiveTestHelper is IntegrationTestHelper {
    constructor() {
        addDeployConfig(new CONFIG_MAINNET_USDC_V3());
        addDeployConfig(new CONFIG_MAINNET_WBTC_V3());
        addDeployConfig(new CONFIG_MAINNET_WETH_V3());
        addDeployConfig(new CONFIG_OPTIMISM_USDC_V3());
        addDeployConfig(new CONFIG_OPTIMISM_WETH_V3());
        addDeployConfig(new CONFIG_ARBITRUM_USDC_V3());
        addDeployConfig(new CONFIG_ARBITRUM_WETH_V3());
        addDeployConfig(new CONFIG_MAINNET_USDC_TEST_V3());
        addDeployConfig(new CONFIG_ARBITRUM_WETH_TEST_V3());
        addDeployConfig(new CONFIG_MAINNET_GHO_V3());
        addDeployConfig(new CONFIG_MAINNET_DAI_V3());
        addDeployConfig(new CONFIG_MAINNET_USDT_V3());
        addDeployConfig(new CONFIG_MAINNET_CRVUSD_V3());
        addDeployConfig(new CONFIG_ARBITRUM_USDCE_V3());
    }

    SupportedContracts public supportedContracts;

    modifier liveTest() {
        if (chainId != 1337 && chainId != 31337) {
            _;
        }
    }

    modifier liveCreditTest(string memory id) {
        if (chainId != 1337 && chainId != 31337) {
            _setupLiveCreditTest(id);
            _;
        }
    }

    modifier attachOrLiveTest() {
        if (chainId != 1337 && chainId != 31337) {
            try vm.envAddress("ATTACH_ADDRESS_PROVIDER") returns (address) {
                _attachCore();
                supportedContracts = new SupportedContracts(chainId);

                address creditManagerToAttach;

                try vm.envAddress("ATTACH_CREDIT_MANAGER") returns (address val) {
                    creditManagerToAttach = val;
                } catch {}

                if (creditManagerToAttach != address(0)) {
                    if (_checkFunctionalSuite(creditManagerToAttach)) {
                        _attachCreditManager(creditManagerToAttach);
                        _;
                        console.log("Successfully ran tests on attached CM: %s", creditManagerToAttach);
                    } else {
                        console.log("Pool or facade for attached CM paused, skipping: %s", creditManagerToAttach);
                    }
                } else {
                    address[] memory cms = cr.getCreditManagers();
                    uint256 len = cms.length;
                    for (uint256 i = 0; i < len; ++i) {
                        if (IVersion(cms[i]).version() >= 3_00) {
                            uint256 snapshot = vm.snapshot();
                            if (_checkFunctionalSuite(cms[i])) {
                                _attachCreditManager(cms[i]);
                                _;
                                console.log("Successfully ran tests on attached CM: %s", cms[i]);
                            } else {
                                console.log("Pool or facade for attached CM paused, skipping: %s", cms[i]);
                            }
                            vm.revertTo(snapshot);
                        }
                    }
                }
            } catch {
                try vm.envString("LIVE_TEST_CONFIG") returns (string memory id) {
                    _setupLiveCreditTest(id);

                    vm.prank(address(gauge));
                    poolQuotaKeeper.updateRates();

                    for (uint256 i = 0; i < creditManagers.length; ++i) {
                        _attachCreditManager(address(creditManagers[i]));
                        _;
                    }
                } catch {
                    revert("Neither attach AP nor live test config was defined.");
                }
            }
        }
    }

    function _setupLiveCreditTest(string memory id) internal {
        _setupCore();
        supportedContracts = new SupportedContracts(chainId);

        PriceFeedDeployer priceFeedDeployer =
            new PriceFeedDeployer(chainId, address(acl), tokenTestSuite, supportedContracts);

        priceFeedDeployer.addPriceFeeds(address(priceOracle));

        IPoolV3DeployConfig config = getDeployConfig(id);

        _deployCreditAndPool(config);

        uint256 len = config.creditManagers().length;
        for (uint256 i = 0; i < len; i++) {
            AdapterDeployer adapterDeployer = new AdapterDeployer(
                address(creditManagers[i]), config.creditManagers()[i].contracts, tokenTestSuite, supportedContracts
            );

            adapterDeployer.connectAdapters();
            _configureAdapters(address(creditManagers[i]), config.creditManagers()[i]);

            address degenNFT = ICreditFacadeV3(ICreditManagerV3(creditManagers[i]).creditFacade()).degenNFT();

            if (degenNFT != address(0)) {
                address minter = DegenNFTMock(degenNFT).minter();

                vm.prank(minter);
                DegenNFTMock(degenNFT).mint(USER, 1000);
            }
        }
    }

    function _configureAdapters(address creditManager, CreditManagerV3DeployParams memory creditManagerParams)
        internal
    {
        // CONVEX AND AURA BOOSTER
        address boosterAdapter = getAdapter(creditManager, Contracts.CONVEX_BOOSTER);

        if (boosterAdapter != address(0)) {
            vm.prank(CONFIGURATOR);
            IConvexV1BoosterAdapter(boosterAdapter).updateSupportedPids();
        }

        boosterAdapter = getAdapter(creditManager, Contracts.AURA_BOOSTER);

        if (boosterAdapter != address(0)) {
            vm.prank(CONFIGURATOR);
            IConvexV1BoosterAdapter(boosterAdapter).updateSupportedPids();
        }

        // ZIRCUIT POOL

        address zircuitAdapter = getAdapter(creditManager, Contracts.ZIRCUIT_POOL);

        if (zircuitAdapter != address(0)) {
            vm.prank(CONFIGURATOR);
            ZircuitPoolAdapter(zircuitAdapter).updateSupportedUnderlyings();
        }

        // BALANCER VAULT
        BalancerPool[] memory bPools = creditManagerParams.balancerPools;

        if (bPools.length != 0) {
            address balancerAdapter = getAdapter(creditManager, Contracts.BALANCER_VAULT);

            for (uint256 i = 0; i < bPools.length; ++i) {
                vm.prank(CONFIGURATOR);
                BalancerV2VaultAdapter(balancerAdapter).setPoolStatus(bPools[i].poolId, PoolStatus(bPools[i].status));
            }
        }
        // UNISWAP V3 ROUTER
        UniswapV3Pair[] memory uniV3Pools = creditManagerParams.uniswapV3Pairs;

        if (uniV3Pools.length != 0) {
            UniswapV3PoolStatus[] memory pools = new UniswapV3PoolStatus[](uniV3Pools.length);

            for (uint256 i = 0; i < uniV3Pools.length; ++i) {
                if (uniV3Pools[i].router != Contracts.UNISWAP_V3_ROUTER) continue;
                pools[i] = UniswapV3PoolStatus({
                    token0: tokenTestSuite.addressOf(uniV3Pools[i].token0),
                    token1: tokenTestSuite.addressOf(uniV3Pools[i].token1),
                    fee: uniV3Pools[i].fee,
                    allowed: true
                });
            }

            address uniV3Adapter = getAdapter(creditManager, Contracts.UNISWAP_V3_ROUTER);

            if (uniV3Adapter != address(0)) {
                vm.prank(CONFIGURATOR);
                UniswapV3Adapter(uniV3Adapter).setPoolStatusBatch(pools);
            }

            pools = new UniswapV3PoolStatus[](uniV3Pools.length);

            for (uint256 i = 0; i < uniV3Pools.length; ++i) {
                if (uniV3Pools[i].router != Contracts.PANCAKESWAP_V3_ROUTER) continue;
                pools[i] = UniswapV3PoolStatus({
                    token0: tokenTestSuite.addressOf(uniV3Pools[i].token0),
                    token1: tokenTestSuite.addressOf(uniV3Pools[i].token1),
                    fee: uniV3Pools[i].fee,
                    allowed: true
                });
            }

            address pancakeswapV3Adapter = getAdapter(creditManager, Contracts.PANCAKESWAP_V3_ROUTER);

            if (pancakeswapV3Adapter != address(0)) {
                vm.prank(CONFIGURATOR);
                UniswapV3Adapter(pancakeswapV3Adapter).setPoolStatusBatch(pools);
            }
        }
        // SIMPLE INTERFACE SWAPPERS
        GenericSwapPair[] memory genericPairs = creditManagerParams.genericSwapPairs;

        if (genericPairs.length != 0) {
            UniswapV2PairStatus[] memory pairs = new UniswapV2PairStatus[](genericPairs.length);

            for (uint256 i = 0; i < genericPairs.length; ++i) {
                if (genericPairs[i].router != Contracts.UNISWAP_V2_ROUTER) continue;
                pairs[i] = UniswapV2PairStatus({
                    token0: tokenTestSuite.addressOf(genericPairs[i].token0),
                    token1: tokenTestSuite.addressOf(genericPairs[i].token1),
                    allowed: true
                });
            }

            address uniV2Adapter = getAdapter(creditManager, Contracts.UNISWAP_V2_ROUTER);

            if (uniV2Adapter != address(0)) {
                vm.prank(CONFIGURATOR);
                UniswapV2Adapter(uniV2Adapter).setPairStatusBatch(pairs);
            }

            pairs = new UniswapV2PairStatus[](genericPairs.length);

            for (uint256 i = 0; i < genericPairs.length; ++i) {
                if (genericPairs[i].router != Contracts.SUSHISWAP_ROUTER) continue;
                pairs[i] = UniswapV2PairStatus({
                    token0: tokenTestSuite.addressOf(genericPairs[i].token0),
                    token1: tokenTestSuite.addressOf(genericPairs[i].token1),
                    allowed: true
                });
            }

            address sushiAdapter = getAdapter(creditManager, Contracts.SUSHISWAP_ROUTER);

            if (sushiAdapter != address(0)) {
                vm.prank(CONFIGURATOR);
                UniswapV2Adapter(sushiAdapter).setPairStatusBatch(pairs);
            }

            pairs = new UniswapV2PairStatus[](genericPairs.length);

            for (uint256 i = 0; i < genericPairs.length; ++i) {
                if (genericPairs[i].router != Contracts.FRAXSWAP_ROUTER) continue;
                pairs[i] = UniswapV2PairStatus({
                    token0: tokenTestSuite.addressOf(genericPairs[i].token0),
                    token1: tokenTestSuite.addressOf(genericPairs[i].token1),
                    allowed: true
                });
            }

            address fraxAdapter = getAdapter(creditManager, Contracts.FRAXSWAP_ROUTER);

            if (fraxAdapter != address(0)) {
                vm.prank(CONFIGURATOR);
                UniswapV2Adapter(fraxAdapter).setPairStatusBatch(pairs);
            }

            CamelotV3PoolStatus[] memory camelotPools = new CamelotV3PoolStatus[](genericPairs.length);

            for (uint256 i = 0; i < genericPairs.length; ++i) {
                if (genericPairs[i].router != Contracts.CAMELOT_V3_ROUTER) continue;
                camelotPools[i] = CamelotV3PoolStatus({
                    token0: tokenTestSuite.addressOf(genericPairs[i].token0),
                    token1: tokenTestSuite.addressOf(genericPairs[i].token1),
                    allowed: true
                });
            }

            address camelotV3Adapter = getAdapter(creditManager, Contracts.CAMELOT_V3_ROUTER);

            if (camelotV3Adapter != address(0)) {
                vm.prank(CONFIGURATOR);
                CamelotV3Adapter(camelotV3Adapter).setPoolStatusBatch(camelotPools);
            }
        }
        // VELODROME V2
        VelodromeV2Pool[] memory velodromeV2Pools = creditManagerParams.velodromeV2Pools;

        if (velodromeV2Pools.length != 0) {
            VelodromeV2PoolStatus[] memory pools = new VelodromeV2PoolStatus[](velodromeV2Pools.length);

            for (uint256 i = 0; i < velodromeV2Pools.length; ++i) {
                pools[i] = VelodromeV2PoolStatus({
                    token0: tokenTestSuite.addressOf(velodromeV2Pools[i].token0),
                    token1: tokenTestSuite.addressOf(velodromeV2Pools[i].token1),
                    stable: velodromeV2Pools[i].stable,
                    factory: velodromeV2Pools[i].factory,
                    allowed: true
                });
            }

            address velodromeV2Adapter = getAdapter(creditManager, Contracts.VELODROME_V2_ROUTER);

            vm.prank(CONFIGURATOR);
            VelodromeV2RouterAdapter(velodromeV2Adapter).setPoolStatusBatch(pools);
        }
    }

    function _checkFunctionalSuite(address creditManager) internal view returns (bool) {
        address pool = ICreditManagerV3(creditManager).pool();
        address creditFacade = ICreditManagerV3(creditManager).creditFacade();

        return !Pausable(pool).paused() && !Pausable(creditFacade).paused();
    }

    function _setUp() public virtual liveTest {
        // lts = new LiveEnvTestSuite();
        // MAINNET_CONFIGURATOR = lts.ROOT_ADDRESS();
        // tokenTestSuite = lts.tokenTestSuite();
        // supportedContracts = lts.supportedContracts();

        // TODO: CHANGE
    }

    //     function getUniV2() internal view returns (IUniswapV2Router02) {
    //         return IUniswapV2Router02(supportedContracts.addressOf(Contracts.UNISWAP_V2_ROUTER));
    //     }

    //     function swapEthToTokens(address onBehalfOf, Tokens t, uint256 amount) internal {
    //         vm.startPrank(onBehalfOf);

    //         getUniV2().swapExactETHForTokens{value: amount}(
    //             0, arrayOf(tokenTestSuite.addressOf(Tokens.WETH), tokenTestSuite.addressOf(t)), onBehalfOf, block.timestamp
    //         );

    //         vm.stopPrank();
    //     }

    //     // [TODO]: add new lib for arrayOf
    //     function arrayOf(address addr0, address addr1) internal pure returns (address[] memory result) {
    //         result = new address[](2);
    //         result[0] = addr0;
    //         result[1] = addr1;
    //     }

    //     function getTokensOfType(TokenType tokenType) internal view returns (Tokens[] memory tokens) {
    //         uint256 tokenCount = tokenTestSuite.tokenCount();

    //         uint256[] memory temp = new uint256[](tokenCount);
    //         uint256 found;

    //         for (uint256 i = 0; i < tokenCount; ++i) {
    //             if (tokenTestSuite.tokenTypes(Tokens(i)) == tokenType) {
    //                 temp[found] = i;
    //                 ++found;
    //             }
    //         }

    //         tokens = new Tokens[](found);

    //         for (uint256 i = 0; i < found; ++i) {
    //             tokens[i] = Tokens(temp[i]);
    //         }
    //     }

    function getAdapter(address creditManager, Contracts target) public view returns (address) {
        return ICreditManagerV3(creditManager).contractToAdapter(supportedContracts.addressOf(target));
    }

    // function getAdapter(Tokens underlying, Contracts target) public view returns (address) {
    //     return _creditManagers[underlying][0].contractToAdapter(supportedContracts.addressOf(target));
    // }

    // function getAdapter(Tokens underlying, Contracts target, uint256 cmIdx) public view returns (address) {
    //     return _creditManagers[underlying][cmIdx].contractToAdapter(supportedContracts.addressOf(target));
    // }
}
