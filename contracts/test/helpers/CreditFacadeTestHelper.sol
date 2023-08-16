// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";

import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";
import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";

import {IntegrationTestHelper} from "@gearbox-protocol/core-v3/contracts/test/helpers/IntegrationTestHelper.sol";

import "../lib/constants.sol";

contract CreditFacadeTestHelper is IntegrationTestHelper {
    function addCollateral(address creditAccount, Tokens t, uint256 amount) internal {
        tokenTestSuite.mint(t, USER, amount);
        tokenTestSuite.approve(t, USER, address(creditManager));

        // vm.startPrank(USER);
        // creditFacade.addCollateral(creditAccount, tokenTestSuite.addressOf(t), amount);
        // vm.stopPrank();
    }

    function addMockPriceFeed(address token, uint256 price) public {
        AggregatorV3Interface priceFeed = new PriceFeedMock(int256(price), 8);

        vm.startPrank(CONFIGURATOR);
        priceOracle.setPriceFeed(token, address(priceFeed), 48 hours);
        vm.stopPrank();
    }
}
