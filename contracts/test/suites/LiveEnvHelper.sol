// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";
import {SupportedContracts, Contracts} from "@gearbox-protocol/sdk/contracts/SupportedContracts.sol";
// import {IUniswapV2Router02} from "../../integrations/uniswap/IUniswapV2Router02.sol";
// import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";

// // import {TokenType} from "../../integrations/TokenType.sol";
// import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";
import {IntegrationTestHelper} from "@gearbox-protocol/core-v3/contracts/test/helpers/IntegrationTestHelper.sol";

contract LiveEnvHelper is IntegrationTestHelper {
    //     LiveEnvTestSuite lts;

    //     address public MAINNET_CONFIGURATOR;
    // mapping(Tokens => CreditManagerV3[]) internal _creditManagers;

    SupportedContracts public supportedContracts;

    modifier liveOnly() {
        if (block.chainid == 1337) {
            _;
        }
    }

    function _setUp() public virtual liveOnly {
        // lts = new LiveEnvTestSuite();
        // MAINNET_CONFIGURATOR = lts.ROOT_ADDRESS();
        // tokenTestSuite = lts.tokenTestSuite();
        // supportedContracts = lts.supportedContracts();

        // TODO: CHANGE
        uint256 chainId = 1;
        supportedContracts = new SupportedContracts(chainId);
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
