// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";

import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";
import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";

import {IntegrationTestHelper} from "@gearbox-protocol/core-v3/contracts/test/helpers/IntegrationTestHelper.sol";

import "../lib/constants.sol";

contract CreditFacadeTestHelper is IntegrationTestHelper {
    function addCollateral(address, /*creditAccount*/ Tokens t, uint256 amount) internal {
        tokenTestSuite.mint(t, USER, amount);
        tokenTestSuite.approve(t, USER, address(creditManager));

        // vm.startPrank(USER);
        // creditFacade.addCollateral(creditAccount, tokenTestSuite.addressOf(t), amount);
        // vm.stopPrank();
    }

    function addMockPriceFeed(address token, uint256 price) public {
        address priceFeed = address(new PriceFeedMock(int256(price), 8));

        vm.prank(CONFIGURATOR);
        priceOracle.setPriceFeed(token, priceFeed, 48 hours, false);
    }
}
