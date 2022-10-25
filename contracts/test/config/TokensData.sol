// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PriceFeedMock } from "@gearbox-protocol/core-v2/contracts/test/mocks/oracles/PriceFeedMock.sol";

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import { Tokens } from "./Tokens.sol";
import { TokenType } from "../../integrations/TokenType.sol";
import { DAI_WETH_RATE } from "../lib/constants.sol";
import { TokenData } from "../suites/TokensTestSuite.sol";

import { WETHMock } from "../mocks/token/WETHMock.sol";
import { LidoMock } from "../mocks/integrations/LidoMock.sol";
import { WstETHV1Mock } from "../mocks/integrations/WstETHV1Mock.sol";
import { ERC20Mock } from "@gearbox-protocol/core-v2/contracts/test/mocks/token/ERC20Mock.sol";
import { cERC20Mock } from "../mocks/token/cERC20Mock.sol";
import { ChainlinkPriceFeedData } from "./PriceFeedDataLive.sol";

struct TestToken {
    Tokens index;
    string symbol;
    uint8 decimals;
    int256 price;
    TokenType tokenType;
    Tokens underlying;
}

contract TokensData {
    TokenData[] tokenData;
    ChainlinkPriceFeedData[] public chainlinkPriceFeedData;
    mapping(Tokens => address) internal addressOf;

    constructor() {
        TestToken[] memory tokensData = getTokensData();
        uint256 len = tokensData.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                addToken(tokensData[i]);
            }
        }
    }

    function getTokenData() external view returns (TokenData[] memory) {
        return tokenData;
    }

    function getTokensData()
        internal
        pure
        returns (TestToken[] memory tokensData)
    {
        TestToken[14] memory coreTokensData = [
            TestToken({
                index: Tokens.DAI,
                symbol: "DAI",
                decimals: 18,
                price: 10**8,
                tokenType: TokenType.NORMAL_TOKEN,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.USDC,
                symbol: "USDC",
                decimals: 6,
                price: 10**8,
                tokenType: TokenType.NORMAL_TOKEN,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.WETH,
                symbol: "WETH",
                decimals: 18,
                price: int256(DAI_WETH_RATE) * 10**8,
                tokenType: TokenType.NORMAL_TOKEN,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.LINK,
                symbol: "LINK",
                decimals: 18,
                price: 15 * 10**8,
                tokenType: TokenType.NORMAL_TOKEN,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.USDT,
                symbol: "USDT",
                decimals: 18,
                price: 99 * 10**7, // .99 for test purposes
                tokenType: TokenType.NORMAL_TOKEN,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.STETH,
                symbol: "stETH",
                decimals: 18,
                price: 3300 * 10**8,
                tokenType: TokenType.NORMAL_TOKEN,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.CRV,
                symbol: "CRV",
                decimals: 18,
                price: 14 * 10**7,
                tokenType: TokenType.NORMAL_TOKEN,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.CVX,
                symbol: "CVX",
                decimals: 18,
                price: 7 * 10**8,
                tokenType: TokenType.NORMAL_TOKEN,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.LUNA,
                symbol: "LUNA",
                decimals: 18,
                price: 1,
                tokenType: TokenType.NORMAL_TOKEN,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.wstETH,
                symbol: "wstETH",
                decimals: 18,
                price: 3300 * 10**8,
                tokenType: TokenType.NORMAL_TOKEN,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.cDAI,
                symbol: "cDAI",
                decimals: 18,
                price: 10**8,
                tokenType: TokenType.C_TOKEN,
                underlying: Tokens.DAI
            }),
            TestToken({
                index: Tokens.cUSDC,
                symbol: "cUSDC",
                decimals: 6,
                price: 10**8,
                tokenType: TokenType.C_TOKEN,
                underlying: Tokens.USDC
            }),
            TestToken({
                index: Tokens.cUSDT,
                symbol: "cUSDT",
                decimals: 18,
                price: 99 * 10**7, // .99 for test purposes
                tokenType: TokenType.C_TOKEN,
                underlying: Tokens.USDT
            }),
            TestToken({
                index: Tokens.cLINK,
                symbol: "cLINK",
                decimals: 18,
                price: 15 * 10**8,
                tokenType: TokenType.C_TOKEN,
                underlying: Tokens.LINK
            })
        ];

        uint256 len = coreTokensData.length;
        tokensData = new TestToken[](len);

        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                tokensData[i] = coreTokensData[i];
            }
        }
    }

    function addToken(TestToken memory token) internal {
        IERC20 t;
        if (token.tokenType == TokenType.NORMAL_TOKEN) {
            if (token.index == Tokens.WETH) {
                t = new WETHMock();
            } else if (token.index == Tokens.STETH) {
                t = new LidoMock();
            } else if (token.index == Tokens.wstETH) {
                t = new WstETHV1Mock(addressOf[Tokens.STETH]);
            } else {
                t = new ERC20Mock(token.symbol, token.symbol, token.decimals);
                ERC20Mock(address(t)).set_minter(msg.sender);
            }
        } else if (token.tokenType == TokenType.C_TOKEN) {
            address underlying = addressOf[token.underlying];
            t = new cERC20Mock(
                token.symbol,
                token.symbol,
                token.decimals,
                underlying
            );
        } else {
            revert("tokenTestSuite: Creating unknown token type");
        }

        TokenData memory td = TokenData({
            id: token.index,
            addr: address(t),
            symbol: token.symbol,
            tokenType: token.tokenType
        });

        addressOf[token.index] = address(t);
        tokenData.push(td);

        AggregatorV3Interface priceFeed = new PriceFeedMock(token.price, 8);

        // prices[token.index] = uint256(token.price);

        // tokenIndexes[address(t)] = token.index;

        // tokenTypes[token.index] = token.tokenType;

        chainlinkPriceFeedData.push(
            ChainlinkPriceFeedData({
                token: token.index,
                priceFeed: address(priceFeed)
            })
        );
        // symbols[token.index] = token.symbol;
        // priceFeedsMap[token.index] = address(priceFeed);
        // tokenCount++;
    }

    function getChainlinkPriceFeedData()
        external
        view
        returns (ChainlinkPriceFeedData[] memory)
    {
        return chainlinkPriceFeedData;
    }
}
