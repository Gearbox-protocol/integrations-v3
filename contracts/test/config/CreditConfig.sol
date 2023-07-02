// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {TokensTestSuite} from "../suites/TokensTestSuite.sol";
import {Tokens} from "./Tokens.sol";

import {CreditManagerOpts, CollateralToken} from "@gearbox-protocol/core-v3/contracts/credit/CreditConfiguratorV3.sol";

import {PriceFeedConfig} from "@gearbox-protocol/core-v2/contracts/oracles/PriceOracleV2.sol";
import {ICreditConfig} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";
import {ITokenTestSuite} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ITokenTestSuite.sol";
import {TokensData} from "./TokensData.sol";
import {ChainlinkPriceFeedData} from "./PriceFeedDataLive.sol";

import {Test} from "forge-std/Test.sol";

import "../lib/constants.sol";

struct CollateralTokensItem {
    Tokens token;
    uint16 liquidationThreshold;
}

/// @title CreditManagerV3TestSuite
/// @notice Deploys contract for unit testing of CreditManagerV3.sol
contract CreditConfig is Test, ICreditConfig {
    uint128 public minBorrowedAmount;
    uint128 public maxBorrowedAmount;

    TokensTestSuite public _tokenTestSuite;
    mapping(Tokens => uint16) public lt;

    address public override underlying;
    address public override wethToken;
    Tokens public underlyingSymbol;

    PriceFeedConfig[] internal priceFeedConfig;

    constructor(TokensTestSuite tokenTestSuite_, Tokens _underlying) {
        uint256 accountAmount = _underlying == Tokens.DAI ? DAI_ACCOUNT_AMOUNT : WETH_ACCOUNT_AMOUNT;

        minBorrowedAmount = uint128(WAD);
        maxBorrowedAmount = uint128(10 * accountAmount);

        _tokenTestSuite = tokenTestSuite_;

        wethToken = tokenTestSuite_.addressOf(Tokens.WETH);
        underlyingSymbol = _underlying;
        underlying = tokenTestSuite_.addressOf(_underlying);

        TokensData td = new TokensData();
        ChainlinkPriceFeedData[] memory chainlinkPriceFeedData = td.getChainlinkPriceFeedData();

        uint256 len = chainlinkPriceFeedData.length;

        for (uint256 i; i < len; ++i) {
            priceFeedConfig.push(
                PriceFeedConfig({
                    token: _tokenTestSuite.addressOf(chainlinkPriceFeedData[i].token),
                    priceFeed: chainlinkPriceFeedData[i].priceFeed
                })
            );
        }
    }

    function getCreditOpts() external override returns (CreditManagerOpts memory) {
        return CreditManagerOpts({
            minBorrowedAmount: minBorrowedAmount,
            maxBorrowedAmount: maxBorrowedAmount,
            collateralTokens: getCollateralTokens(),
            degenNFT: address(0),
            blacklistHelper: address(0),
            expirable: false
        });
    }

    function getCollateralTokens() public override returns (CollateralToken[] memory collateralTokens) {
        CollateralTokensItem[11] memory collateralTokenOpts = [
            CollateralTokensItem({token: Tokens.USDC, liquidationThreshold: 9000}),
            CollateralTokensItem({token: Tokens.USDT, liquidationThreshold: 8800}),
            CollateralTokensItem({token: Tokens.DAI, liquidationThreshold: 8300}),
            CollateralTokensItem({token: Tokens.WETH, liquidationThreshold: 8300}),
            CollateralTokensItem({token: Tokens.LINK, liquidationThreshold: 7300}),
            CollateralTokensItem({token: Tokens.CRV, liquidationThreshold: 7300}),
            CollateralTokensItem({token: Tokens.CVX, liquidationThreshold: 7300}),
            CollateralTokensItem({token: Tokens.STETH, liquidationThreshold: 7300}),
            CollateralTokensItem({token: Tokens.cUSDC, liquidationThreshold: 9000}),
            CollateralTokensItem({token: Tokens.cUSDT, liquidationThreshold: 8800}),
            CollateralTokensItem({token: Tokens.cDAI, liquidationThreshold: 8300})
        ];

        lt[underlyingSymbol] = 9300;

        uint256 len = collateralTokenOpts.length;
        collateralTokens = new CollateralToken[](len - 1);
        uint256 j;
        for (uint256 i = 0; i < len; i++) {
            if (collateralTokenOpts[i].token == underlyingSymbol) continue;

            lt[collateralTokenOpts[i].token] = collateralTokenOpts[i].liquidationThreshold;

            collateralTokens[j] = CollateralToken({
                token: _tokenTestSuite.addressOf(collateralTokenOpts[i].token),
                liquidationThreshold: collateralTokenOpts[i].liquidationThreshold
            });
            j++;
        }
    }

    function getAccountAmount() public view override returns (uint256) {
        return (underlyingSymbol == Tokens.DAI) ? DAI_ACCOUNT_AMOUNT : WETH_ACCOUNT_AMOUNT;
    }

    function getPriceFeeds() external view override returns (PriceFeedConfig[] memory) {
        return priceFeedConfig;
    }

    function tokenTestSuite() external view override returns (ITokenTestSuite) {
        return _tokenTestSuite;
    }
}
