// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.10;

import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";
import {SupportedContracts, Contracts} from "@gearbox-protocol/sdk/contracts/SupportedContracts.sol";
import {IPoolV3DeployConfig} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";

import {PriceFeedDeployer} from "@gearbox-protocol/oracles-v3/contracts/test/suites/PriceFeedDeployer.sol";
import {IntegrationTestHelper} from "@gearbox-protocol/core-v3/contracts/test/helpers/IntegrationTestHelper.sol";
import {AdapterDeployer} from "./AdapterDeployer.sol";

import {CONFIG_MAINNET_USDC_MT_V3} from "../config/USDC_MT_config.sol";
import {CONFIG_MAINNET_WBTC_MT_V3} from "../config/WBTC_MT_config.sol";
import {CONFIG_MAINNET_WETH_MT_V3} from "../config/WETH_MT_config.sol";

import {CONFIG_MAINNET_USDC_LEV_V3} from "../config/USDC_Lev_config.sol";

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

    // function getAdapter(address creditManager, Contracts target) public view returns (address) {
    //     return creditManager(creditManager).contractToAdapter(supportedContracts.addressOf(target));
    // }

    // function getAdapter(Tokens underlying, Contracts target) public view returns (address) {
    //     return _creditManagers[underlying][0].contractToAdapter(supportedContracts.addressOf(target));
    // }

    // function getAdapter(Tokens underlying, Contracts target, uint256 cmIdx) public view returns (address) {
    //     return _creditManagers[underlying][cmIdx].contractToAdapter(supportedContracts.addressOf(target));
    // }
}
