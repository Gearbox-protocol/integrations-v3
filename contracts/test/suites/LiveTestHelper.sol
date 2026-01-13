// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.10;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {DegenNFTMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/DegenNFTMock.sol";

import "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {SupportedContracts, Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";
import {
    IPoolV3DeployConfig,
    CreditManagerV3DeployParams,
    UniswapV3Pair,
    GenericSwapPair,
    VelodromeV2Pool,
    MellowUnderlyingConfig,
    PendlePair
} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";

import {PriceFeedDeployer} from "@gearbox-protocol/oracles-v3/contracts/test/suites/PriceFeedDeployer.sol";
import {IntegrationTestHelper} from "@gearbox-protocol/core-v3/contracts/test/helpers/IntegrationTestHelper.sol";
import {AdapterDeployer} from "./AdapterDeployer.sol";

import {IConvexV1BoosterAdapter} from "../../interfaces/convex/IConvexV1BoosterAdapter.sol";
import {UniswapV2Adapter} from "../../adapters/uniswap/UniswapV2.sol";
import {UniswapV3Adapter} from "../../adapters/uniswap/UniswapV3.sol";
import {VelodromeV2RouterAdapter} from "../../adapters/velodrome/VelodromeV2RouterAdapter.sol";
import {CamelotV3Adapter} from "../../adapters/camelot/CamelotV3Adapter.sol";
import {PendleRouterAdapter} from "../../adapters/pendle/PendleRouterAdapter.sol";
import {MellowVaultAdapter} from "../../adapters/mellow/MellowVaultAdapter.sol";

import {UniswapV2PairStatus} from "../../interfaces/uniswap/IUniswapV2Adapter.sol";
import {UniswapV3PoolStatus} from "../../interfaces/uniswap/IUniswapV3Adapter.sol";
import {VelodromeV2PoolStatus} from "../../interfaces/velodrome/IVelodromeV2RouterAdapter.sol";
import {CamelotV3PoolStatus} from "../../interfaces/camelot/ICamelotV3Adapter.sol";
import {PendlePairStatus, PendleStatus, PendleTokenType} from "../../interfaces/pendle/IPendleRouterAdapter.sol";
import {MellowUnderlyingStatus} from "../../interfaces/mellow/IMellowVaultAdapter.sol";

import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

import "forge-std/console.sol";

contract LiveTestHelper is IntegrationTestHelper {
    constructor() {}

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
            try vm.envAddress("ATTACH_CREDIT_MANAGER") returns (address creditManagerToAttach) {
                if (creditManagerToAttach != address(0)) {
                    if (_checkFunctionalSuite(creditManagerToAttach)) {
                        _attachCreditManager(creditManagerToAttach);
                        _;
                        console.log("Successfully ran tests on attached CM: %s", creditManagerToAttach);
                    } else {
                        console.log("Pool or facade for attached CM paused, skipping: %s", creditManagerToAttach);
                    }
                }
            } catch {
                try vm.envAddress("ATTACH_POOL") returns (address poolToAttach) {
                    _attachPool(poolToAttach);
                    supportedContracts = new SupportedContracts(chainId);

                    address[] memory cms = pool.creditManagers();
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
                    console.log("Successfully ran tests on attached pool: %s", poolToAttach);
                } catch {
                    try vm.envString("LIVE_TEST_CONFIG") returns (string memory id) {
                        _setupLiveCreditTest(id);

                        vm.prank(address(gauge));
                        poolQuotaKeeper.updateRates();

                        for (uint256 i = 0; i < creditManagers.length; ++i) {
                            uint256 s = vm.snapshot();
                            _attachCreditManager(address(creditManagers[i]));
                            _;
                            vm.revertTo(s);
                        }
                    } catch {
                        revert(
                            "Live/attach tests require the attached pool/CM address or live test config. Please set one of the env variables: ATTACH_POOL or ATTACH_CREDIT_MANAGER or LIVE_TEST_CONFIG"
                        );
                    }
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

        // PENDLE_ROUTER
        PendlePair[] memory pPairs = creditManagerParams.adapterConfig.pendlePairs;

        if (pPairs.length != 0) {
            PendlePairStatus[] memory pairs = new PendlePairStatus[](pPairs.length);

            for (uint256 i = 0; i < pPairs.length; ++i) {
                pairs[i] = PendlePairStatus({
                    market: pPairs[i].market,
                    inputToken: tokenTestSuite.addressOf(pPairs[i].inputToken),
                    pendleToken: tokenTestSuite.addressOf(pPairs[i].pendleToken),
                    pendleTokenType: PendleTokenType.PT,
                    status: PendleStatus(pPairs[i].status)
                });
            }

            address pendleRouterAdapter = getAdapter(creditManager, Contracts.PENDLE_ROUTER);
            vm.prank(CONFIGURATOR);
            PendleRouterAdapter(pendleRouterAdapter).setPairStatusBatch(pairs);
        }

        // MELLOW VAULTS
        MellowUnderlyingConfig[] memory mellowConfigs = creditManagerParams.adapterConfig.mellowUnderlyings;

        if (mellowConfigs.length != 0) {
            for (uint256 i = 0; i < mellowConfigs.length; ++i) {
                address mellowAdapter = getAdapter(creditManager, mellowConfigs[i].vault);

                MellowUnderlyingStatus[] memory ms = new MellowUnderlyingStatus[](1);
                ms[0] = MellowUnderlyingStatus({
                    underlying: tokenTestSuite.addressOf(mellowConfigs[i].underlying), allowed: true
                });

                vm.prank(CONFIGURATOR);
                MellowVaultAdapter(mellowAdapter).setUnderlyingStatusBatch(ms);
            }
        }

        // UNISWAP V3 ROUTER
        UniswapV3Pair[] memory uniV3Pools = creditManagerParams.adapterConfig.uniswapV3Pairs;

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

            for (uint256 i = 0; i < uniV3Pools.length; ++i) {
                if (uniV3Pools[i].router != Contracts.VELODROME_CL_ROUTER) continue;
                pools[i] = UniswapV3PoolStatus({
                    token0: tokenTestSuite.addressOf(uniV3Pools[i].token0),
                    token1: tokenTestSuite.addressOf(uniV3Pools[i].token1),
                    fee: uniV3Pools[i].fee,
                    allowed: true
                });
            }

            address velodromeCLAdapter = getAdapter(creditManager, Contracts.VELODROME_CL_ROUTER);

            if (velodromeCLAdapter != address(0)) {
                vm.prank(CONFIGURATOR);
                UniswapV3Adapter(velodromeCLAdapter).setPoolStatusBatch(pools);
            }
        }
        // SIMPLE INTERFACE SWAPPERS
        GenericSwapPair[] memory genericPairs = creditManagerParams.adapterConfig.genericSwapPairs;

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
        VelodromeV2Pool[] memory velodromeV2Pools = creditManagerParams.adapterConfig.velodromeV2Pools;

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

    function _setUp() public virtual liveTest {}

    function getAdapter(address creditManager, Contracts target) public view returns (address) {
        return ICreditManagerV3(creditManager).contractToAdapter(supportedContracts.addressOf(target));
    }
}
