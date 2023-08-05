// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";

import {WstETHV1Adapter} from "../../../../adapters/lido/WstETHV1.sol";
import {WstETHV1Mock} from "../../../mocks/integrations/WstETHV1Mock.sol";
import {WstETHPriceFeed} from "@gearbox-protocol/oracles-v3/contracts/oracles/lido/WstETHPriceFeed.sol";
import {IwstETH} from "../../../../integrations/lido/IwstETH.sol";

// TEST
import "../../../lib/constants.sol";
import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";

import {AdapterTestHelper} from "../AdapterTestHelper.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

uint256 constant STETH_PER_TOKEN = (110 * WAD) / 100;

/// @title WstETHV1AdapterTest
/// @notice Designed for unit test purposes only
contract WstETHV1AdapterTest is Test, AdapterTestHelper {
    // using StringUtils for string;

    WstETHV1Adapter public adapter;
    WstETHV1Mock public wstETHMock;
    address public stETH;

    function setUp() public {
        _setUp(Tokens.STETH);

        stETH = tokenTestSuite.addressOf(Tokens.STETH);

        wstETHMock = new WstETHV1Mock(stETH);
        wstETHMock.setStEthPerToken(STETH_PER_TOKEN);

        vm.startPrank(CONFIGURATOR);

        priceOracle.setPriceFeed(
            address(wstETHMock),
            address(
                new WstETHPriceFeed(
                    address(addressProvider),
                    address(wstETHMock),
                    priceOracle.priceFeeds(stETH),
                    2 hours
                )
            ),
            0
        );

        creditConfigurator.addCollateralToken(address(wstETHMock), 8300);

        adapter = new WstETHV1Adapter(
            address(creditManager),
            address(wstETHMock)
        );

        creditConfigurator.allowAdapter(address(adapter));

        vm.stopPrank();
        tokenTestSuite.mint(Tokens.WETH, USER, 10 * WETH_ACCOUNT_AMOUNT);

        vm.label(address(adapter), "ADAPTER");
        vm.label(address(stETH), "STETH");
        vm.label(address(wstETHMock), "WSTETH_MOCK");
    }

    //
    // HELPERS
    //
    function _openStETHTestCreditAccount(bool wrap) internal returns (address creditAccount, uint256 amount) {
        uint256 initialStETHbalance;
        (creditAccount, initialStETHbalance) = _openTestCreditAccount();

        if (wrap) {
            executeOneLineMulticall(creditAccount, address(adapter), abi.encodeCall(adapter.wrapAll, ()));

            amount = (((initialStETHbalance - 1) * WAD) / STETH_PER_TOKEN);
            expectBalance(Tokens.STETH, creditAccount, 1);
            expectBalance(address(wstETHMock), creditAccount, amount);

            expectTokenIsEnabled(creditAccount, Tokens.STETH, false);
            expectTokenIsEnabled(creditAccount, address(wstETHMock), true);
        } else {
            amount = initialStETHbalance;

            expectBalance(Tokens.STETH, creditAccount, initialStETHbalance);
            expectBalance(address(wstETHMock), creditAccount, 0);

            expectTokenIsEnabled(creditAccount, Tokens.STETH, true);
            expectTokenIsEnabled(creditAccount, address(wstETHMock), false);
        }
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [AWSTV1-1]: constructor sets correct values
    function test_AWSTV1_01_constructor_sets_correct_values() public {
        assertEq(address(adapter.stETH()), tokenTestSuite.addressOf(Tokens.STETH), "Incorrect token");
        assertEq(
            adapter.stETHTokenMask(),
            creditManager.getTokenMaskOrRevert(tokenTestSuite.addressOf(Tokens.STETH)),
            "Incorrect stETH mask"
        );
        assertEq(
            adapter.wstETHTokenMask(), creditManager.getTokenMaskOrRevert(address(wstETHMock)), "Incorrect wstETH mask"
        );
    }

    /// @dev [AWSTV1-2]: constructor reverts if token is not allowed
    function test_AWSTV1_02_constructor_reverts_if_token_is_not_allowed() public {
        ERC20Mock forbiddenToken = new ERC20Mock("Forbid", "FBD", 18);

        WstETHV1Mock forbidWstETHV1Mock = new WstETHV1Mock(
            address(forbiddenToken)
        );

        vm.expectRevert(TokenNotAllowedException.selector);
        new WstETHV1Adapter(
            address(creditManager),
            address(forbidWstETHV1Mock)
        );

        WstETHV1Mock notAllowedWstETHV1Mock = new WstETHV1Mock(
            tokenTestSuite.addressOf(Tokens.STETH)
        );
        vm.expectRevert(TokenNotAllowedException.selector);
        new WstETHV1Adapter(
            address(creditManager),
            address(notAllowedWstETHV1Mock)
        );
    }

    // /// @dev [AWSTV1-3]: wrap and unwrap reverts if user has no account
    // function test_AWSTV1_03_wrap_and_unwrap_if_user_has_no_account() public {
    //     vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
    //     executeOneLineMulticall(creditAccount, address(adapter), abi.encodeCall(adapter.wrapAll, ()));

    //     vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
    //     executeOneLineMulticall(creditAccount, address(adapter), abi.encodeCall(adapter.wrap, (1000)));

    //     vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
    //     executeOneLineMulticall(creditAccount, address(adapter), abi.encodeCall(adapter.unwrapAll, ()));

    //     vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
    //     executeOneLineMulticall(creditAccount, address(adapter), abi.encodeCall(adapter.unwrap, (1000)));
    // }

    //
    // WRAP
    //

    /// @dev [AWSTV1-4]: wrapAll works for user as expected
    function test_AWSTV1_04_wrapAll_works_for_user_as_expected() public {
        setUp();
        (address creditAccount, uint256 initialStETHbalance) = _openStETHTestCreditAccount(false);

        expectAllowance(Tokens.STETH, creditAccount, address(wstETHMock), 0);

        bytes memory expectedCallData = abi.encodeCall(IwstETH.wrap, (initialStETHbalance - 1));

        expectMulticallStackCalls(
            address(adapter), address(wstETHMock), USER, expectedCallData, stETH, address(wstETHMock), true
        );

        executeOneLineMulticall(creditAccount, address(adapter), abi.encodeCall(WstETHV1Adapter.wrapAll, ()));

        expectBalance(Tokens.STETH, creditAccount, 1);

        expectBalance(address(wstETHMock), creditAccount, ((initialStETHbalance - 1) * WAD) / STETH_PER_TOKEN);

        expectAllowance(Tokens.STETH, creditAccount, address(wstETHMock), 1);

        expectTokenIsEnabled(creditAccount, Tokens.STETH, false);
        expectTokenIsEnabled(creditAccount, address(wstETHMock), true);

        expectTokenIsEnabled(creditAccount, address(wstETHMock), true);
    }

    /// @dev [AWSTV1-5]: wrap works for user as expected
    function test_AWSTV1_05_wrap_uint256_works_for_user_as_expected() public {
        setUp();
        (address creditAccount, uint256 initialStETHbalance) = _openStETHTestCreditAccount(false);

        expectAllowance(Tokens.STETH, creditAccount, address(wstETHMock), 0);

        bytes memory expectedCallData = abi.encodeCall(IwstETH.wrap, (WETH_EXCHANGE_AMOUNT));

        expectMulticallStackCalls(
            address(adapter), address(wstETHMock), USER, expectedCallData, stETH, address(wstETHMock), true
        );

        executeOneLineMulticall(creditAccount, address(adapter), expectedCallData);

        expectBalance(Tokens.STETH, creditAccount, initialStETHbalance - WETH_EXCHANGE_AMOUNT);

        expectBalance(address(wstETHMock), creditAccount, (WETH_EXCHANGE_AMOUNT * WAD) / STETH_PER_TOKEN);

        expectAllowance(Tokens.STETH, creditAccount, address(wstETHMock), 1);

        expectTokenIsEnabled(creditAccount, address(wstETHMock), true);

        expectTokenIsEnabled(creditAccount, address(wstETHMock), true);
    }

    //
    // UNWRAP
    //

    /// @dev [AWSTV1-6]: unwrapAll works for user as expected
    function test_AWSTV1_06_unwrapAll_works_for_user_as_expected() public {
        setUp();

        (address creditAccount, uint256 initialWstETHamount) = _openStETHTestCreditAccount(true);

        bytes memory expectedCallData = abi.encodeCall(IwstETH.unwrap, (initialWstETHamount - 1));

        expectMulticallStackCalls(
            address(adapter), address(wstETHMock), USER, expectedCallData, stETH, address(wstETHMock), false
        );

        executeOneLineMulticall(creditAccount, address(adapter), abi.encodeCall(WstETHV1Adapter.unwrapAll, ()));

        expectBalance(Tokens.STETH, creditAccount, ((initialWstETHamount - 1) * STETH_PER_TOKEN) / WAD + 1);

        expectBalance(address(wstETHMock), creditAccount, 1);

        // There is not need to approve wstETH to itself, so nothing in terms of allowance should be done
        expectAllowance(address(wstETHMock), creditAccount, address(wstETHMock), 0);

        expectTokenIsEnabled(creditAccount, address(wstETHMock), false);
        expectTokenIsEnabled(creditAccount, Tokens.STETH, true);

        expectTokenIsEnabled(creditAccount, address(wstETHMock), true);
    }

    /// @dev [AWSTV1-7]: unwrap works for user as expected
    function test_AWSTV1_07_unwrap_uint256_works_for_user_as_expected() public {
        setUp();
        (address creditAccount, uint256 wstETHamount) = _openStETHTestCreditAccount(true);

        expectAllowance(address(wstETHMock), creditAccount, address(wstETHMock), 0);

        uint256 amount = wstETHamount / 2;

        bytes memory expectedCallData = abi.encodeCall(IwstETH.unwrap, (amount));

        expectMulticallStackCalls(
            address(adapter), address(wstETHMock), USER, expectedCallData, stETH, address(wstETHMock), false
        );

        executeOneLineMulticall(creditAccount, address(adapter), expectedCallData);

        expectBalance(Tokens.STETH, creditAccount, ((amount) * STETH_PER_TOKEN) / WAD + 1);

        // +1 cause it keeps from deposit there
        expectBalance(address(wstETHMock), creditAccount, wstETHamount - amount);

        // There is not need to approve wstETH to itself, so nothing in terms of allowance should be done
        expectAllowance(address(wstETHMock), creditAccount, address(wstETHMock), 0);

        expectTokenIsEnabled(creditAccount, Tokens.STETH, true);

        expectTokenIsEnabled(creditAccount, address(wstETHMock), true);
    }
}
