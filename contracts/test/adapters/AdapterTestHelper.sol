// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { ICreditManagerV2, ICreditManagerV2Events } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";
import { ICreditFacadeEvents } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacade.sol";
import { IAdapterExceptions } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

// TEST
import "../lib/constants.sol";

// SUITES
import { TokensTestSuite } from "../suites/TokensTestSuite.sol";
import { Tokens } from "../config/Tokens.sol";

import { CreditFacadeTestSuite } from "@gearbox-protocol/core-v2/contracts/test/suites/CreditFacadeTestSuite.sol";

import { BalanceHelper } from "../helpers/BalanceHelper.sol";
import { CreditFacadeTestHelper } from "../helpers/CreditFacadeTestHelper.sol";
import { CreditConfig } from "../config/CreditConfig.sol";

/// @title UniswapV2AdapterTest
/// @notice Designed for unit test purposes only
contract AdapterTestHelper is
    DSTest,
    ICreditManagerV2Events,
    ICreditFacadeEvents,
    IAdapterExceptions,
    BalanceHelper,
    CreditFacadeTestHelper
{
    function _setUp() internal {
        _setUp(Tokens.DAI);
    }

    function _setUp(Tokens t) internal {
        require(
            t == Tokens.DAI || t == Tokens.WETH || t == Tokens.STETH,
            "Unsupported token"
        );

        tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{ value: 100 * WAD }();

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

    function expectFastCheckStackCalls(
        address, // adapter,
        address targetContract,
        address borrower,
        bytes memory callData,
        address tokenIn,
        address, // tokenOut,
        bool safeExecute,
        bool allowTokenIn
    ) internal {
        if (allowTokenIn) {
            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    ICreditManagerV2.approveCreditAccount.selector,
                    borrower,
                    targetContract,
                    tokenIn,
                    type(uint256).max
                )
            );
        }

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.executeOrder.selector,
                borrower,
                targetContract,
                callData
            )
        );

        evm.expectEmit(true, true, false, false);
        emit ExecuteOrder(borrower, targetContract);

        if (allowTokenIn) {
            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    ICreditManagerV2.approveCreditAccount.selector,
                    borrower,
                    targetContract,
                    tokenIn,
                    safeExecute ? 1 : type(uint256).max
                )
            );
        }
    }

    function expectFastCheckStackCalls(
        address adapter,
        address targetContract,
        address borrower,
        bytes memory callData,
        address tokenIn,
        address tokenOut,
        bool safeExecute
    ) internal {
        expectFastCheckStackCalls(
            adapter,
            targetContract,
            borrower,
            callData,
            tokenIn,
            tokenOut,
            safeExecute,
            true
        );
    }

    function expectMulticallStackCalls(
        address, // adapter,
        address targetContract,
        address borrower,
        bytes memory callData,
        address tokenIn,
        address, // tokenOut,
        bool safeExecute,
        bool allowTokenIn
    ) internal {
        evm.expectEmit(true, false, false, false);
        emit MultiCallStarted(borrower);

        if (allowTokenIn) {
            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    ICreditManagerV2.approveCreditAccount.selector,
                    address(creditFacade),
                    targetContract,
                    tokenIn,
                    type(uint256).max
                )
            );
        }

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.executeOrder.selector,
                address(creditFacade),
                targetContract,
                callData
            )
        );

        evm.expectEmit(true, true, false, false);
        emit ExecuteOrder(address(creditFacade), targetContract);

        if (allowTokenIn) {
            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    ICreditManagerV2.approveCreditAccount.selector,
                    address(creditFacade),
                    targetContract,
                    tokenIn,
                    safeExecute ? 1 : type(uint256).max
                )
            );
        }
    }

    function expectMulticallStackCalls(
        address adapter,
        address targetContract,
        address borrower,
        bytes memory callData,
        address tokenIn,
        address tokenOut,
        bool safeExecute
    ) internal {
        expectMulticallStackCalls(
            adapter,
            targetContract,
            borrower,
            callData,
            tokenIn,
            tokenOut,
            safeExecute,
            true
        );
    }
}
