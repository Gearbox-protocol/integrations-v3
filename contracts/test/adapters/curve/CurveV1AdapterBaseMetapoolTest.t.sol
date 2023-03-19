// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {CurveV1AdapterBase} from "../../../adapters/curve/CurveV1_Base.sol";
import {ICurveV1Adapter} from "../../../interfaces/curve/ICurveV1Adapter.sol";
import {ICurvePool} from "../../../integrations/curve/ICurvePool.sol";

import {CurveV1MetapoolMock} from "../../mocks/integrations/CurveV1MetapoolMock.sol";
import {MultiCall} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacade.sol";

import {Tokens} from "../../config/Tokens.sol";

// TEST
import "../../lib/constants.sol";

import {CurveV1AdapterHelper} from "./CurveV1AdapterHelper.sol";

// EXCEPTIONS

/// @title CurveV1AdapterBaseTest
/// @notice Designed for unit test purposes only
contract CurveV1AdapterBaseMetaPoolTest is DSTest, CurveV1AdapterHelper {
    ICurveV1Adapter public adapter;
    CurveV1MetapoolMock public curveV1Mock;

    function setUp() public {
        _setUpCurveMetapoolSuite();

        tokenTestSuite.balanceOf(Tokens.DAI, _curveV1MockAddr);

        curveV1Mock = CurveV1MetapoolMock(_curveV1MockAddr);

        curveV1Mock.setRate(0, 1, RAY); // 3CRV / LINK = 1

        curveV1Mock.setRateUnderlying(0, 1, RAY); // DAI / LINK = 1 USD
        curveV1Mock.setRateUnderlying(0, 2, (99 * RAY) / 100); // USDC / LINK = .99
        curveV1Mock.setRateUnderlying(0, 3, (99 * RAY) / 100); // USDT / LINK = .99
        curveV1Mock.setRateUnderlying(2, 3, RAY); // USDC / USDT = 1

        adapter = CurveV1AdapterBase(_adapterAddr);
    }

    ///
    ///
    ///  TESTS
    ///
    ///
    /// @dev [ACV1-M-1]: constructor sets correct values
    function test_ACV1_M_01_constructor_sets_correct_values() public {
        assertEq(address(adapter.metapoolBase()), address(curveV1Mock.basePool()), "Incorrect base pool");
    }

    /// @dev [ACV1-M-2]: exchange_underlying works correctly
    function test_ACV1_M_02_exchange_underlying_works_correctly() public {
        address tokenIn = tokenTestSuite.addressOf(Tokens.cLINK);
        address tokenOut = tokenTestSuite.addressOf(Tokens.cUSDT);

        (address creditAccount,) = _openTestCreditAccount();

        addCollateral(Tokens.cLINK, LINK_ACCOUNT_AMOUNT);

        bytes memory callData = abi.encodeWithSignature(
            "exchange_underlying(int128,int128,uint256,uint256)",
            0,
            3,
            LINK_EXCHANGE_AMOUNT,
            (LINK_EXCHANGE_AMOUNT * 99) / 100
        );

        expectMulticallStackCalls(address(adapter), address(curveV1Mock), USER, callData, tokenIn, tokenOut, true);

        executeOneLineMulticall(address(adapter), callData);

        expectBalance(Tokens.cLINK, creditAccount, LINK_ACCOUNT_AMOUNT - LINK_EXCHANGE_AMOUNT);

        expectBalance(Tokens.cUSDT, creditAccount, (LINK_EXCHANGE_AMOUNT * 99) / 100);
        expectTokenIsEnabled(tokenOut, true);
    }

    /// @dev [ACV1-M-3]: exchange_all_underlying works correctly
    function test_ACV1_M_03_exchange_all_underlying_works_correctly() public {
        address tokenIn = tokenTestSuite.addressOf(Tokens.cLINK);
        address tokenOut = tokenTestSuite.addressOf(Tokens.cUSDT);

        (address creditAccount,) = _openTestCreditAccount();

        addCollateral(Tokens.cLINK, LINK_ACCOUNT_AMOUNT);

        bytes memory callData = abi.encodeWithSignature(
            "exchange_underlying(int128,int128,uint256,uint256)",
            0,
            3,
            LINK_ACCOUNT_AMOUNT - 1,
            ((LINK_ACCOUNT_AMOUNT - 1) * 99) / 100
        );

        expectMulticallStackCalls(address(adapter), address(curveV1Mock), USER, callData, tokenIn, tokenOut, true);

        executeOneLineMulticall(
            address(adapter),
            abi.encodeWithSignature("exchange_all_underlying(int128,int128,uint256)", 0, 3, (RAY * 99) / 100)
        );

        expectBalance(Tokens.cLINK, creditAccount, 1);

        expectBalance(Tokens.cUSDT, creditAccount, ((LINK_ACCOUNT_AMOUNT - 1) * 99) / 100);

        expectTokenIsEnabled(tokenIn, false);
        expectTokenIsEnabled(tokenOut, true);
    }
}
