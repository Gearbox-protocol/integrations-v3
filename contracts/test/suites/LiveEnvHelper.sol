// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;
import { LiveEnvTestSuite } from "./LiveEnvTestSuite.sol";
import { CheatCodes, HEVM_ADDRESS } from "@gearbox-protocol/core-v2/contracts/test/lib/cheatCodes.sol";
import { Tokens } from "../config/Tokens.sol";

import { SupportedContracts, Contracts } from "../config/SupportedContracts.sol";
import { IUniswapV2Router02 } from "../../integrations/uniswap/IUniswapV2Router02.sol";
import { MultiCall } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacade.sol";
import { TokenType } from "../../integrations/TokenType.sol";
import { TokensTestSuite } from "../suites/TokensTestSuite.sol";

contract LiveEnvHelper {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);
    LiveEnvTestSuite lts;

    address public MAINNET_CONFIGURATOR;

    TokensTestSuite public tokenTestSuite;
    SupportedContracts public supportedContracts;

    modifier liveOnly() {
        if (block.chainid == 1337) {
            _;
        }
    }

    function _setUp() public virtual liveOnly {
        lts = new LiveEnvTestSuite();
        MAINNET_CONFIGURATOR = lts.ROOT_ADDRESS();
        tokenTestSuite = lts.tokenTestSuite();
        supportedContracts = lts.supportedContracts();
    }

    function getUniV2() internal view returns (IUniswapV2Router02) {
        return
            IUniswapV2Router02(
                supportedContracts.addressOf(Contracts.UNISWAP_V2_ROUTER)
            );
    }

    function swapEthToTokens(
        address onBehalfOf,
        Tokens t,
        uint256 amount
    ) internal {
        evm.startPrank(onBehalfOf);

        getUniV2().swapExactETHForTokens{ value: amount }(
            0,
            arrayOf(
                tokenTestSuite.addressOf(Tokens.WETH),
                tokenTestSuite.addressOf(t)
            ),
            onBehalfOf,
            block.timestamp
        );

        evm.stopPrank();
    }

    // [TODO]: add new lib for arrayOf
    function arrayOf(address addr0, address addr1)
        internal
        pure
        returns (address[] memory result)
    {
        result = new address[](2);
        result[0] = addr0;
        result[1] = addr1;
    }

    function multicallBuilder()
        internal
        pure
        returns (MultiCall[] memory calls)
    {}

    function multicallBuilder(MultiCall memory call1)
        internal
        pure
        returns (MultiCall[] memory calls)
    {
        calls = new MultiCall[](1);
        calls[0] = call1;
    }

    function multicallBuilder(MultiCall memory call1, MultiCall memory call2)
        internal
        pure
        returns (MultiCall[] memory calls)
    {
        calls = new MultiCall[](2);
        calls[0] = call1;
        calls[1] = call2;
    }

    function multicallBuilder(
        MultiCall memory call1,
        MultiCall memory call2,
        MultiCall memory call3
    ) internal pure returns (MultiCall[] memory calls) {
        calls = new MultiCall[](3);
        calls[0] = call1;
        calls[1] = call2;
        calls[2] = call3;
    }

    function getTokensOfType(TokenType tokenType)
        internal
        view
        returns (Tokens[] memory tokens)
    {
        uint256 tokenCount = tokenTestSuite.tokenCount();

        uint256[] memory temp = new uint256[](tokenCount);
        uint256 found;

        for (uint256 i = 0; i < tokenCount; ++i) {
            if (tokenTestSuite.tokenTypes(Tokens(i)) == tokenType) {
                temp[found] = i;
                ++found;
            }
        }

        tokens = new Tokens[](found);

        for (uint256 i = 0; i < found; ++i) {
            tokens[i] = Tokens(temp[i]);
        }
    }
}
