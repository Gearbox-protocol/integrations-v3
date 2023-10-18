// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.10;

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {SupportedContracts, Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";
import {
    IPoolV3DeployConfig,
    CreditManagerV3DeployParams,
    BalancerPool,
    UniswapV3Pair,
    UniswapV2Pair
} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";

import {PriceFeedDeployer} from "@gearbox-protocol/oracles-v3/contracts/test/suites/PriceFeedDeployer.sol";
import {IntegrationTestHelper} from "@gearbox-protocol/core-v3/contracts/test/helpers/IntegrationTestHelper.sol";
import {AdapterDeployer} from "./AdapterDeployer.sol";

import {CONFIG_MAINNET_USDC_MT_V3} from "../config/USDC_MT_config.sol";
import {CONFIG_MAINNET_WBTC_MT_V3} from "../config/WBTC_MT_config.sol";
import {CONFIG_MAINNET_WETH_MT_V3} from "../config/WETH_MT_config.sol";

import {CONFIG_MAINNET_USDC_LEV_V3} from "../config/USDC_Lev_config.sol";

import {IConvexV1BoosterAdapter} from "../../interfaces/convex/IConvexV1BoosterAdapter.sol";
import {BalancerV2VaultAdapter} from "../../adapters/balancer/BalancerV2VaultAdapter.sol";
import {UniswapV2Adapter} from "../../adapters/uniswap/UniswapV2.sol";
import {UniswapV3Adapter} from "../../adapters/uniswap/UniswapV3.sol";
import {PoolStatus} from "../../interfaces/balancer/IBalancerV2VaultAdapter.sol";
import {UniswapV2PairStatus} from "../../interfaces/uniswap/IUniswapV2Adapter.sol";
import {UniswapV3PoolStatus} from "../../interfaces/uniswap/IUniswapV3Adapter.sol";

import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

import "forge-std/console.sol";

contract LiveTestHelper is IntegrationTestHelper {
    constructor() {
        addDeployConfig(new CONFIG_MAINNET_USDC_MT_V3());
        addDeployConfig(new CONFIG_MAINNET_WBTC_MT_V3());
        addDeployConfig(new CONFIG_MAINNET_WETH_MT_V3());
        addDeployConfig(new CONFIG_MAINNET_USDC_LEV_V3());
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

    modifier attachOrSetupLiveCreditTest(string memory id) {
        try vm.envAddress("ATTACH_ADDRESS_PROVIDER") returns (address val) {
            _attachCore();
            address[] memory cms = cr.getCreditManagers();
            uint256 len = cms.length;
            for (uint256 i = 0; i < len; ++i) {
                _attachCreditManager(cms[i]);
                _;
            }
        } catch {
            _setupLiveCreditTest(id);
            _;
        }
    }

    function _setupLiveCreditTest(string memory id) internal {
        _setupCore();
        console.log(tokenTestSuite.addressOf(Tokens.MKR));
        supportedContracts = new SupportedContracts(chainId);

        PriceFeedDeployer priceFeedDeployer =
            new PriceFeedDeployer(chainId, address(addressProvider), tokenTestSuite, supportedContracts);

        priceFeedDeployer.addPriceFeeds(address(priceOracle));

        IPoolV3DeployConfig config = getDeployConfig(id);

        _deployCreditAndPool(config);

        uint256 len = config.creditManagers().length;
        for (uint256 i = 0; i < len; i++) {
            AdapterDeployer adapterDeployer =
            new AdapterDeployer(address(creditManagers[i]), config.creditManagers()[i].contracts, tokenTestSuite, supportedContracts );

            adapterDeployer.connectAdapters();
            _configureAdapters(address(creditManagers[i]), config.creditManagers()[i]);
        }
    }

    function _configureAdapters(address creditManager, CreditManagerV3DeployParams memory creditManagerParams)
        internal
    {
        // CONVEX AND AURA BOOSTER
        address boosterAdapter = getAdapter(creditManager, Contracts.CONVEX_BOOSTER);

        if (boosterAdapter != address(0)) {
            vm.prank(CONFIGURATOR);
            IConvexV1BoosterAdapter(boosterAdapter).updateStakedPhantomTokensMap();
        }

        boosterAdapter = getAdapter(creditManager, Contracts.AURA_BOOSTER);

        if (boosterAdapter != address(0)) {
            vm.prank(CONFIGURATOR);
            IConvexV1BoosterAdapter(boosterAdapter).updateStakedPhantomTokensMap();
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
                pools[i] = UniswapV3PoolStatus({
                    token0: tokenTestSuite.addressOf(uniV3Pools[i].token0),
                    token1: tokenTestSuite.addressOf(uniV3Pools[i].token1),
                    fee: uniV3Pools[i].fee,
                    allowed: true
                });
            }

            address uniV3Adapter = getAdapter(creditManager, Contracts.UNISWAP_V3_ROUTER);

            vm.prank(CONFIGURATOR);
            UniswapV3Adapter(uniV3Adapter).setPoolStatusBatch(pools);
        }
        // UNISWAP V2 AND SUSHISWAP
        UniswapV2Pair[] memory uniV2Pairs = creditManagerParams.uniswapV2Pairs;

        if (uniV2Pairs.length != 0) {
            UniswapV2PairStatus[] memory pairs = new UniswapV2PairStatus[](uniV2Pairs.length);

            for (uint256 i = 0; i < uniV2Pairs.length; ++i) {
                if (uniV2Pairs[i].router != Contracts.UNISWAP_V2_ROUTER) continue;
                pairs[i] = UniswapV2PairStatus({
                    token0: tokenTestSuite.addressOf(uniV2Pairs[i].token0),
                    token1: tokenTestSuite.addressOf(uniV2Pairs[i].token1),
                    allowed: true
                });
            }

            address uniV2Adapter = getAdapter(creditManager, Contracts.UNISWAP_V2_ROUTER);

            vm.prank(CONFIGURATOR);
            UniswapV2Adapter(uniV2Adapter).setPairStatusBatch(pairs);

            pairs = new UniswapV2PairStatus[](uniV2Pairs.length);

            for (uint256 i = 0; i < uniV2Pairs.length; ++i) {
                if (uniV2Pairs[i].router != Contracts.SUSHISWAP_ROUTER) continue;
                pairs[i] = UniswapV2PairStatus({
                    token0: tokenTestSuite.addressOf(uniV2Pairs[i].token0),
                    token1: tokenTestSuite.addressOf(uniV2Pairs[i].token1),
                    allowed: true
                });
            }

            address sushiAdapter = getAdapter(creditManager, Contracts.SUSHISWAP_ROUTER);

            vm.prank(CONFIGURATOR);
            UniswapV2Adapter(sushiAdapter).setPairStatusBatch(pairs);
        }
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
