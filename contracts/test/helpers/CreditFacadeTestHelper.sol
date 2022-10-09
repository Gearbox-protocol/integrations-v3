// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { TokensTestSuite } from "../suites/TokensTestSuite.sol";
import { CreditFacadeTestEngine } from "@gearbox-protocol/core-v2/contracts/test/helpers/CreditFacadeTestEngine.sol";

import { PriceFeedMock } from "@gearbox-protocol/core-v2/contracts/test/mocks/oracles/PriceFeedMock.sol";
import { Tokens } from "../config/Tokens.sol";

import "../lib/constants.sol";

/// @title CreditManagerTestSuite
/// @notice Deploys contract for unit testing of CreditManager.sol
contract CreditFacadeTestHelper is CreditFacadeTestEngine {
    function expectTokenIsEnabled(Tokens t, bool expectedState) internal {
        expectTokenIsEnabled(t, expectedState, "");
    }

    function expectTokenIsEnabled(
        Tokens t,
        bool expectedState,
        string memory reason
    ) internal {
        expectTokenIsEnabled(
            tokenTestSuite().addressOf(t),
            expectedState,
            reason
        );
    }

    function addCollateral(Tokens t, uint256 amount) internal {
        tokenTestSuite().mint(t, USER, amount);
        tokenTestSuite().approve(t, USER, address(creditManager));

        evm.startPrank(USER);
        creditFacade.addCollateral(USER, tokenTestSuite().addressOf(t), amount);
        evm.stopPrank();
    }

    function tokenTestSuite() private returns (TokensTestSuite) {
        return TokensTestSuite(payable(address(cft.tokenTestSuite())));
    }

    function addMockPriceFeed(address token, uint256 price) public {
        AggregatorV3Interface priceFeed = new PriceFeedMock(int256(price), 8);

        evm.startPrank(CONFIGURATOR);
        cft.priceOracle().addPriceFeed(token, address(priceFeed));
        evm.stopPrank();
    }
}
