// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {
    ICreditManagerV2,
    ICreditManagerV2Events
} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV2.sol";
import {ICreditFacadeEvents} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacade.sol";

// TEST
import "../lib/constants.sol";

// SUITES
import {TokensTestSuite} from "../suites/TokensTestSuite.sol";
import {Tokens} from "../config/Tokens.sol";

import {CreditFacadeTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/CreditFacadeTestSuite.sol";

import {BalanceHelper} from "../helpers/BalanceHelper.sol";
import {CreditFacadeTestHelper} from "../helpers/CreditFacadeTestHelper.sol";
import {CreditConfig} from "../config/CreditConfig.sol";

contract AdapterTestHelper is
    DSTest,
    ICreditManagerV2Events,
    ICreditFacadeEvents,
    BalanceHelper,
    CreditFacadeTestHelper
{
    function _setUp() internal {
        _setUp(Tokens.DAI);
    }

    function _setUp(Tokens t) internal {
        require(t == Tokens.DAI || t == Tokens.WETH || t == Tokens.STETH, "Unsupported token");

        tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{value: 100 * WAD}();

        CreditConfig creditConfig = new CreditConfig(tokenTestSuite, t);

        cft = new CreditFacadeTestSuite(creditConfig);

        underlying = cft.underlying();

        creditManager = cft.creditManager();
        creditFacade = cft.creditFacade();
        creditConfigurator = cft.creditConfigurator();
    }

    function _getUniswapDeadline() internal view returns (uint256) {
        return block.timestamp + 1;
    }

    function expectMulticallStackCalls(
        address, // adapter,
        address targetContract,
        address borrower,
        bytes memory callData,
        address tokenIn,
        address, // tokenOut,
        bool allowTokenIn
    ) internal {
        evm.expectEmit(true, false, false, false);
        emit MultiCallStarted(borrower);

        if (allowTokenIn) {
            evm.expectCall(
                address(creditManager),
                abi.encodeCall(ICreditManagerV2.approveCreditAccount, (targetContract, tokenIn, type(uint256).max))
            );
        }

        evm.expectCall(
            address(creditManager), abi.encodeCall(ICreditManagerV2.executeOrder, (targetContract, callData))
        );

        evm.expectEmit(true, false, false, false);
        emit ExecuteOrder(targetContract);

        if (allowTokenIn) {
            evm.expectCall(
                address(creditManager),
                abi.encodeCall(ICreditManagerV2.approveCreditAccount, (targetContract, tokenIn, 1))
            );
        }

        evm.expectEmit(false, false, false, false);
        emit MultiCallFinished();
    }
}
