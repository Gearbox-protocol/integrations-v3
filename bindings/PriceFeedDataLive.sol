// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {Tokens} from "./Tokens.sol";
import {Contracts} from "./SupportedContracts.sol";

struct ChainlinkPriceFeedData {
    Tokens token;
    address priceFeed;
}

enum CurvePoolType {
    STABLE,
    CRYPTO
}

struct CurvePriceFeedData {
    CurvePoolType poolType;
    Tokens lpToken;
    Tokens[] assets;
    Contracts pool;
}

struct CurveLikePriceFeedData {
    Tokens lpToken;
    Tokens curveToken;
}

struct SingeTokenPriceFeedData {
    Tokens token;
}

struct CompositePriceFeedData {
    Tokens token;
    address targetToBaseFeed;
    address baseToUSDFeed;
}

struct BoundedPriceFeedData {
    Tokens token;
    address priceFeed;
    uint256 upperBound;
}

contract PriceFeedDataLive {
    ChainlinkPriceFeedData[] chainlinkPriceFeeds;
    SingeTokenPriceFeedData[] zeroPriceFeeds;
    CurvePriceFeedData[] curvePriceFeeds;
    CurveLikePriceFeedData[] likeCurvePriceFeeds;
    SingeTokenPriceFeedData[] yearnPriceFeeds;
    BoundedPriceFeedData[] boundedPriceFeeds;
    CompositePriceFeedData[] compositePriceFeeds;
    SingeTokenPriceFeedData wstethPriceFeed;

    constructor(uint8 networkId) {
        if (networkId == 1) {
            // $CHAINLINK_PRICE_FEEDS
            // $CURVE_LIKE_PRICE_FEEDS
            // $COMPOSITE_PRICE_FEEDS
            // $BOUNDED_PRICE_FEEDS
        } else if (networkId == 2) {
            // $GOERLI_CHAINLINK_PRICE_FEEDS
            // $GOERLI_CURVE_LIKE_PRICE_FEEDS
            // $GOERLI_COMPOSITE_PRICE_FEEDS
            // $GOERLI_BOUNDED_PRICE_FEEDS
        }

        // $ZERO_PRICE_FEEDS
        // $CURVE_PRICE_FEEDS
        // $YEARN_PRICE_FEEDS
        // $WSTETH_PRICE_FEED
    }

    function assets(Tokens t1, Tokens t2) internal pure returns (Tokens[] memory result) {
        result = new Tokens[](2);
        result[0] = t1;
        result[1] = t2;
    }

    function assets(Tokens t1, Tokens t2, Tokens t3) internal pure returns (Tokens[] memory result) {
        result = new Tokens[](3);
        result[0] = t1;
        result[1] = t2;
        result[2] = t3;
    }

    function assets(Tokens t1, Tokens t2, Tokens t3, Tokens t4) internal pure returns (Tokens[] memory result) {
        result = new Tokens[](4);
        result[0] = t1;
        result[1] = t2;
        result[2] = t3;
        result[3] = t4;
    }
}
