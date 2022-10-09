// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox.fi, 2021
pragma solidity ^0.8.10;
import { Tokens } from "../config/Tokens.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { PriceFeedDataLive } from "../config/PriceFeedDataLive.sol";
import { PriceFeedConfig } from "@gearbox-protocol/core-v2/contracts/oracles/PriceOracle.sol";
import { ZeroPriceFeed } from "@gearbox-protocol/core-v2/contracts/oracles/ZeroPriceFeed.sol";
import { YearnPriceFeed } from "../../oracles/yearn/YearnPriceFeed.sol";
import { WstETHPriceFeed } from "../../oracles/lido/WstETHPriceFeed.sol";
import { CurveV1StETHPoolGateway } from "../../adapters/curve/CurveV1_stETHGateway.sol";

import { ISupportedContracts, Contracts } from "../config/SupportedContracts.sol";

import { CurveLP2PriceFeed } from "../../oracles/curve/CurveLP2PriceFeed.sol";
import { CurveLP3PriceFeed } from "../../oracles/curve/CurveLP3PriceFeed.sol";
import { CurveLP4PriceFeed } from "../../oracles/curve/CurveLP4PriceFeed.sol";

import { ICurveRegistry } from "../../integrations/curve/ICurveRegistry.sol";
import { IYVault } from "../../integrations/yearn/IYVault.sol";
import { IwstETH } from "../../integrations/lido/IwstETH.sol";

import "@gearbox-protocol/core-v2/contracts/test/lib/test.sol";
import { CheatCodes, HEVM_ADDRESS } from "@gearbox-protocol/core-v2/contracts/test/lib/cheatCodes.sol";

import { TokensTestSuite } from "./TokensTestSuite.sol";

address constant CURVE_REGISTRY = 0x90E00ACe148ca3b23Ac1bC8C240C2a7Dd9c2d7f5;

contract LivePriceFeedDeployer is PriceFeedDataLive {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);
    mapping(address => address) public priceFeeds;
    PriceFeedConfig[] priceFeedConfig;

    constructor(
        uint8 networkId,
        address addressProvider,
        TokensTestSuite tokenTestSuite,
        ISupportedContracts supportedContracts
    ) PriceFeedDataLive(networkId) {
        // CHAINLINK PRICE FEEDS
        uint256 len = chainlinkPriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                address pf = chainlinkPriceFeeds[i].priceFeed;
                Tokens t = chainlinkPriceFeeds[i].token;
                setPriceFeed(tokenTestSuite.addressOf(t), pf);

                string memory description = string(
                    abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t))
                );
                evm.label(pf, description);
            }
        }

        // ZERO PRICE FEEDS
        len = zeroPriceFeeds.length;
        if (len > 0) {
            address zeroPF = address(new ZeroPriceFeed());
            unchecked {
                for (uint256 i; i < len; ++i) {
                    setPriceFeed(
                        tokenTestSuite.addressOf(zeroPriceFeeds[i].token),
                        zeroPF
                    );

                    evm.label(zeroPF, "ZERO PRICEFEED");
                }
            }
        }

        // CURVE PRICE FEEDS
        len = curvePriceFeeds.length;

        unchecked {
            for (uint256 i; i < len; ++i) {
                Tokens lpToken = curvePriceFeeds[i].lpToken;
                uint256 nCoins = curvePriceFeeds[i].assets.length;
                address pf;

                address pool = supportedContracts.addressOf(
                    curvePriceFeeds[i].pool
                );
                if (curvePriceFeeds[i].pool == Contracts.CURVE_STETH_GATEWAY) {
                    pool = CurveV1StETHPoolGateway(payable(pool)).pool();
                }

                string memory description = string(
                    abi.encodePacked(
                        "PRICEFEED_",
                        tokenTestSuite.symbols(lpToken)
                    )
                );

                if (nCoins == 2) {
                    pf = address(
                        new CurveLP2PriceFeed(
                            addressProvider,
                            pool,
                            priceFeeds[
                                tokenTestSuite.addressOf(
                                    curvePriceFeeds[i].assets[0]
                                )
                            ],
                            priceFeeds[
                                tokenTestSuite.addressOf(
                                    curvePriceFeeds[i].assets[1]
                                )
                            ],
                            description
                        )
                    );
                } else if (nCoins == 3) {
                    pf = address(
                        new CurveLP3PriceFeed(
                            addressProvider,
                            pool,
                            priceFeeds[
                                tokenTestSuite.addressOf(
                                    curvePriceFeeds[i].assets[0]
                                )
                            ],
                            priceFeeds[
                                tokenTestSuite.addressOf(
                                    curvePriceFeeds[i].assets[1]
                                )
                            ],
                            priceFeeds[
                                tokenTestSuite.addressOf(
                                    curvePriceFeeds[i].assets[2]
                                )
                            ],
                            description
                        )
                    );
                } else if (nCoins == 4) {
                    pf = address(
                        new CurveLP4PriceFeed(
                            addressProvider,
                            pool,
                            priceFeeds[
                                tokenTestSuite.addressOf(
                                    curvePriceFeeds[i].assets[0]
                                )
                            ],
                            priceFeeds[
                                tokenTestSuite.addressOf(
                                    curvePriceFeeds[i].assets[1]
                                )
                            ],
                            priceFeeds[
                                tokenTestSuite.addressOf(
                                    curvePriceFeeds[i].assets[2]
                                )
                            ],
                            priceFeeds[
                                tokenTestSuite.addressOf(
                                    curvePriceFeeds[i].assets[3]
                                )
                            ],
                            description
                        )
                    );
                }

                setPriceFeed(tokenTestSuite.addressOf(lpToken), pf);
                evm.label(pf, description);
            }
        }

        // CURVE LIKE PRICEFEEDS
        len = likeCurvePriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                address token = tokenTestSuite.addressOf(
                    likeCurvePriceFeeds[i].lpToken
                );
                address curveToken = tokenTestSuite.addressOf(
                    likeCurvePriceFeeds[i].curveToken
                );
                setPriceFeed(token, priceFeeds[curveToken]);
            }
        }

        // YEARN PRICE FEEDS

        len = yearnPriceFeeds.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                Tokens t = yearnPriceFeeds[i].token;
                address yVault = tokenTestSuite.addressOf(t);
                address underlying = IYVault(yVault).token();

                address pf = address(
                    new YearnPriceFeed(
                        addressProvider,
                        yVault,
                        priceFeeds[underlying]
                    )
                );

                setPriceFeed(yVault, pf);

                string memory description = string(
                    abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t))
                );
                evm.label(pf, description);
            }
        }

        // WSTETH_PRICE_FEED
        unchecked {
            Tokens t = wstethPriceFeed.token;
            address wsteth = tokenTestSuite.addressOf(t);
            address steth = IwstETH(wsteth).stETH();

            address pf = address(
                new WstETHPriceFeed(addressProvider, wsteth, priceFeeds[steth])
            );

            setPriceFeed(wsteth, pf);

            string memory description = string(
                abi.encodePacked("PRICEFEED_", tokenTestSuite.symbols(t))
            );
            evm.label(pf, description);
        }
    }

    function setPriceFeed(address token, address priceFeed) internal {
        priceFeeds[token] = priceFeed;
        priceFeedConfig.push(
            PriceFeedConfig({ token: token, priceFeed: priceFeed })
        );
    }

    function getPriceFeeds() external view returns (PriceFeedConfig[] memory) {
        return priceFeedConfig;
    }
}
