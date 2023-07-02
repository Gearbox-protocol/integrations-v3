// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {TokensTestSuite} from "../suites/TokensTestSuite.sol";

import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";
import {Tokens} from "../config/Tokens.sol";

import "../lib/constants.sol";

/// @title CreditManagerV3TestSuite
/// @notice Deploys contract for unit testing of CreditManagerV3.sol
contract CreditFacadeTestHelper is CreditFacadeV3TestEngine {
    function expectTokenIsEnabled(Tokens t, bool expectedState) internal {
        expectTokenIsEnabled(t, expectedState, "");
    }

    function expectTokenIsEnabled(Tokens t, bool expectedState, string memory reason) internal {
        expectTokenIsEnabled(tokenTestSuite().addressOf(t), expectedState, reason);
    }

    function addCollateral(Tokens t, uint256 amount) internal {
        tokenTestSuite().mint(t, USER, amount);
        tokenTestSuite().approve(t, USER, address(CreditManagerV3));

        vm.startPrank(USER);
        creditFacade.addCollateral(USER, tokenTestSuite().addressOf(t), amount);
        vm.stopPrank();
    }

    function tokenTestSuite() private view returns (TokensTestSuite) {
        return TokensTestSuite(payable(address(cft.tokenTestSuite())));
    }

    function addMockPriceFeed(address token, uint256 price) public {
        AggregatorV3Interface priceFeed = new PriceFeedMock(int256(price), 8);

        vm.startPrank(CONFIGURATOR);
        cft.priceOracle().addPriceFeed(token, address(priceFeed));
        vm.stopPrank();
    }
}
