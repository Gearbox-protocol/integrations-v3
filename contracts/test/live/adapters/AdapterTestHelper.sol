// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {
    ICreditManagerV3,
    ICreditManagerV3Events
} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditFacadeV3Events} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";

// TEST
import "../../lib/constants.sol";

// SUITES
import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";
import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";

// import {BalanceHelper} from "../../helpers/BalanceHelper.sol";
// import {CreditFacadeTestHelper} from "../../helpers/CreditFacadeTestHelper.sol";
import {IntegrationTestHelper} from "@gearbox-protocol/core-v3/contracts/test/helpers/IntegrationTestHelper.sol";
// import {CreditConfig} from "../../config/CreditConfig.sol";

contract AdapterTestHelper is Test, ICreditManagerV3Events, ICreditFacadeV3Events, IntegrationTestHelper {
    function _setUp() internal {
        _setUp(Tokens.DAI);
    }

    function _setUp(Tokens t) internal {
        require(t == Tokens.DAI || t == Tokens.WETH || t == Tokens.STETH, "Unsupported token");

        tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{value: 100 * WAD}();

        // CreditConfig creditConfig = new CreditConfig(tokenTestSuite, t);

        // cft = new CreditFacadeV3TestSuite(creditConfig);

        // underlying = cft.underlying();

        // CreditManagerV3 = cft.CreditManagerV3();
        // creditFacade = cft.creditFacade();
        // CreditConfiguratorV3 = cft.CreditConfiguratorV3();
    }

    function _getUniswapDeadline() internal view returns (uint256) {
        return block.timestamp + 1;
    }

    function expectMulticallStackCalls(
        address creditAccount,
        address borrower,
        address targetContract,
        bytes memory callData,
        address tokenIn,
        bool allowTokenIn
    ) internal {
        vm.expectEmit(true, true, false, false);
        emit StartMultiCall(creditAccount, borrower);

        if (allowTokenIn) {
            vm.expectCall(
                address(creditManager),
                abi.encodeCall(ICreditManagerV3.approveCreditAccount, (tokenIn, type(uint256).max))
            );
        }

        vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.execute, (callData)));

        vm.expectEmit(true, false, false, false);
        emit Execute(creditAccount, targetContract);

        if (allowTokenIn) {
            vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.approveCreditAccount, (tokenIn, 1)));
        }

        vm.expectEmit(false, false, false, false);
        emit FinishMultiCall();
    }
}
