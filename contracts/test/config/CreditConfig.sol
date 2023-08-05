// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";
import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";

import {CreditManagerOpts, CollateralToken} from "@gearbox-protocol/core-v3/contracts/credit/CreditConfiguratorV3.sol";

// import {PriceFeedConfig} from "@gearbox-protocol/core-v3/contracts/oracles/PriceOracleV3.sol";
import {ICreditConfig, PriceFeedConfig} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ICreditConfig.sol";
import {ITokenTestSuite} from "@gearbox-protocol/core-v3/contracts/test/interfaces/ITokenTestSuite.sol";
import {TokensDataLive} from "@gearbox-protocol/sdk/contracts/TokensData.sol";
import {ChainlinkPriceFeedData} from "@gearbox-protocol/sdk/contracts/PriceFeedDataLive.sol";

import {Test} from "forge-std/Test.sol";

import "../lib/constants.sol";

struct CollateralTokensItem {
    Tokens token;
    uint16 liquidationThreshold;
}

/// @title CreditManagerV3TestSuite
/// @notice Deploys contract for unit testing of CreditManagerV3.sol
contract CreditConfig is Test, ICreditConfig {
    uint128 public minDebt;
    uint128 public maxDebt;

    TokensTestSuite public _tokenTestSuite;
    mapping(Tokens => uint16) public lt;

    address public override underlying;
    address public override wethToken;
    Tokens public underlyingSymbol;

    PriceFeedConfig[] internal priceFeedConfig;

    constructor(TokensTestSuite tokenTestSuite_, Tokens _underlying) {
        uint256 accountAmount = _underlying == Tokens.DAI ? DAI_ACCOUNT_AMOUNT : WETH_ACCOUNT_AMOUNT;

        minDebt = uint128(WAD);
        maxDebt = uint128(10 * accountAmount);

        _tokenTestSuite = tokenTestSuite_;

        wethToken = tokenTestSuite_.addressOf(Tokens.WETH);
        underlyingSymbol = _underlying;
        underlying = tokenTestSuite_.addressOf(_underlying);

        TokensDataLive td = new TokensDataLive();
        // ChainlinkPriceFeedData[] memory chainlinkPriceFeedData = td.getChainlinkPriceFeedData();

        // uint256 len = chainlinkPriceFeedData.length;

        // for (uint256 i; i < len; ++i) {
        //     priceFeedConfig.push(
        //         PriceFeedConfig({
        //             token: _tokenTestSuite.addressOf(chainlinkPriceFeedData[i].token),
        //             priceFeed: chainlinkPriceFeedData[i].priceFeed
        //         })
        //     );
        // }
    }

    // /// @dev A struct representing the initial Credit Manager configuration parameters
    // struct CreditManagerOpts {
    //     /// @dev The minimal debt principal amount
    //     uint128 minDebt;
    //     /// @dev The maximal debt principal amount
    //     uint128 maxDebt;
    //     /// @dev The initial list of collateral tokens to allow
    //     CollateralToken[] collateralTokens;
    //     /// @dev Address of IDegenNFTV2, address(0) if whitelisted mode is not used
    //     address degenNFT;
    //     /// @dev Address of BlacklistHelper, address(0) if the underlying is not blacklistable
    //     address withdrawalManager;
    //     /// @dev Whether the Credit Manager is connected to an expirable pool (and the CreditFacadeV3 is expirable)
    //     bool expirable;
    // }

    function getCreditOpts() external override returns (CreditManagerOpts memory) {
        return CreditManagerOpts({
            minDebt: minDebt,
            maxDebt: maxDebt,
            collateralTokens: getCollateralTokens(),
            degenNFT: address(0),
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
