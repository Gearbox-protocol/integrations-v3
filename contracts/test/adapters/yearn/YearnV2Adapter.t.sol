// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IAdapterExceptions} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";
import {
    ICreditManagerV2,
    ICreditManagerV2Exceptions
} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";

import {YearnV2Adapter} from "../../../adapters/yearn/YearnV2.sol";

import {YearnV2Mock} from "../../mocks/integrations/YearnV2Mock.sol";

import {Tokens} from "../../suites/TokensTestSuite.sol";
import {YearnPriceFeed} from "../../../oracles/yearn/YearnPriceFeed.sol";

// TEST
import "../../lib/constants.sol";

import {AdapterTestHelper} from "../AdapterTestHelper.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v2/contracts/test/mocks/token/ERC20Mock.sol";

uint256 constant PRICE_PER_SHARE = (110 * WAD) / 100;

/// @title YearnV2AdapterTest
/// @notice Designed for unit test purposes only
contract YearnV2AdapterTest is DSTest, AdapterTestHelper {
    YearnV2Adapter public adapter;
    YearnV2Mock public yearnV2Mock;
    address public token;
    address public yvDAI;

    function setUp() public {
        _setUp();

        token = tokenTestSuite.addressOf(Tokens.DAI);

        yearnV2Mock = new YearnV2Mock(token);
        yearnV2Mock.setPricePerShare(PRICE_PER_SHARE);

        yvDAI = address(yearnV2Mock);

        evm.startPrank(CONFIGURATOR);

        cft.priceOracle().addPriceFeed(
            yvDAI,
            address(
                new YearnPriceFeed(
                    address(cft.addressProvider()),
                    yvDAI,
                    cft.priceOracle().priceFeeds(token)
                )
            )
        );

        creditConfigurator.addCollateralToken(yvDAI, 8300);

        adapter = new YearnV2Adapter(
            address(creditManager),
            address(yearnV2Mock)
        );

        creditConfigurator.allowContract(address(yearnV2Mock), address(adapter));

        evm.stopPrank();
        tokenTestSuite.mint(Tokens.DAI, USER, 10 * DAI_ACCOUNT_AMOUNT);

        evm.label(address(adapter), "ADAPTER");
        evm.label(address(yearnV2Mock), "YEARN_MOCK");
    }

    //
    // HELPERS
    //
    function _openYVDaiTestCreditAccount() internal returns (address creditAccount, uint256 yAmount) {
        uint256 initialDAIbalance;
        (creditAccount, initialDAIbalance) = _openTestCreditAccount();

        yAmount = (((initialDAIbalance - 1) * WAD) / PRICE_PER_SHARE);

        executeOneLineMulticall(address(adapter), abi.encodeWithSignature("deposit()"));

        expectBalance(Tokens.DAI, creditAccount, 1);
        expectBalance(yvDAI, creditAccount, yAmount);

        expectTokenIsEnabled(Tokens.DAI, false);
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [AYV2-1]: constructor sets correct values
    function test_AYV2_01_constructor_sets_correct_values() public {
        assertEq(address(adapter.token()), tokenTestSuite.addressOf(Tokens.DAI), "Incorrect token");
        assertEq(
            adapter.tokenMask(),
            creditManager.tokenMasksMap(tokenTestSuite.addressOf(Tokens.DAI)),
            "Incorrect underlying token mask"
        );
        assertEq(adapter.yTokenMask(), creditManager.tokenMasksMap(yvDAI), "Incorrect vault token mask");
    }

    /// @dev [AYV2-2]: constructor reverts if token is not allowed
    function test_AYV2_02_constructor_reverts_if_token_is_not_allowed() public {
        ERC20Mock forbiddenToken = new ERC20Mock("Forbid", "FBD", 18);

        YearnV2Mock forbidYearnV2Mock = new YearnV2Mock(
            address(forbiddenToken)
        );

        evm.expectRevert(IAdapterExceptions.TokenNotAllowedException.selector);
        new YearnV2Adapter(address(creditManager), address(forbidYearnV2Mock));

        YearnV2Mock notAllowedYearnV2Mock = new YearnV2Mock(
            tokenTestSuite.addressOf(Tokens.DAI)
        );

        evm.expectRevert(IAdapterExceptions.TokenNotAllowedException.selector);

        new YearnV2Adapter(
            address(creditManager),
            address(notAllowedYearnV2Mock)
        );
    }

    /// @dev [AYV2-3]: depost(*) and witdraw(*) revert if user has no account
    function test_AYV2_03_deposit_and_withdraw_revert_if_uses_has_no_account() public {
        evm.expectRevert(ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(address(adapter), abi.encodeWithSignature("deposit()"));

        evm.expectRevert(ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(address(adapter), abi.encodeWithSignature("deposit(uint256)", 1000));

        evm.expectRevert(ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(address(adapter), abi.encodeWithSignature("deposit(uint256,address)", 1000, address(0)));

        evm.expectRevert(ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(address(adapter), abi.encodeWithSignature("withdraw()"));

        evm.expectRevert(ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(address(adapter), abi.encodeWithSignature("withdraw(uint256)", 1000));

        evm.expectRevert(ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(
            address(adapter), abi.encodeWithSignature("withdraw(uint256,address)", 1000, address(0))
        );

        evm.expectRevert(ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(
            address(adapter), abi.encodeWithSignature("withdraw(uint256,address,uint256)", 1000, address(0), 2)
        );
    }

    /// @dev [AYV2-4]: deposit works for user as expected
    function test_AYV2_04_deposit_works_for_user_as_expected() public {
        setUp();
        (address creditAccount, uint256 initialDAIbalance) = _openTestCreditAccount();

        expectAllowance(Tokens.DAI, creditAccount, address(yearnV2Mock), 0);

        bytes memory expectedCallData = abi.encodeWithSignature("deposit(uint256)", initialDAIbalance - 1);

        expectMulticallStackCalls(
            address(adapter), address(yearnV2Mock), USER, expectedCallData, token, address(yearnV2Mock), true
        );

        executeOneLineMulticall(address(adapter), abi.encodeWithSignature("deposit()"));

        expectBalance(Tokens.DAI, creditAccount, 1);

        expectBalance(yvDAI, creditAccount, ((initialDAIbalance - 1) * WAD) / PRICE_PER_SHARE);

        expectAllowance(Tokens.DAI, creditAccount, address(yearnV2Mock), 1);

        expectTokenIsEnabled(Tokens.DAI, false);
        expectTokenIsEnabled(yvDAI, true);

        expectSafeAllowance(address(yearnV2Mock));
    }

    /// @dev [AYV2-5]: deposit(uint256) works for user as expected
    function test_AYV2_05_deposit_uint256_works_for_user_as_expected() public {
        setUp();
        (address creditAccount, uint256 initialDAIbalance) = _openTestCreditAccount();

        expectAllowance(Tokens.DAI, creditAccount, address(yearnV2Mock), 0);

        bytes memory expectedCallData = abi.encodeWithSignature("deposit(uint256)", DAI_EXCHANGE_AMOUNT);

        expectMulticallStackCalls(
            address(adapter), address(yearnV2Mock), USER, expectedCallData, token, address(yearnV2Mock), true
        );

        executeOneLineMulticall(address(adapter), abi.encodeWithSignature("deposit(uint256)", DAI_EXCHANGE_AMOUNT));

        expectBalance(Tokens.DAI, creditAccount, initialDAIbalance - DAI_EXCHANGE_AMOUNT);

        expectBalance(yvDAI, creditAccount, (DAI_EXCHANGE_AMOUNT * WAD) / PRICE_PER_SHARE);

        expectAllowance(Tokens.DAI, creditAccount, address(yearnV2Mock), 1);

        expectTokenIsEnabled(yvDAI, true);

        expectSafeAllowance(address(yearnV2Mock));
    }

    /// @dev [AYV2-6]: deposit(uint256, address) works for user as expected
    function test_AYV2_06_deposit_uint256_address_works_for_user_as_expected() public {
        setUp();
        (address creditAccount, uint256 initialDAIbalance) = _openTestCreditAccount();

        expectAllowance(Tokens.DAI, creditAccount, address(yearnV2Mock), 0);

        bytes memory expectedCallData = abi.encodeWithSignature("deposit(uint256)", DAI_EXCHANGE_AMOUNT);

        bytes memory callData = abi.encodeWithSignature("deposit(uint256,address)", DAI_EXCHANGE_AMOUNT, address(0));

        expectMulticallStackCalls(
            address(adapter), address(yearnV2Mock), USER, expectedCallData, token, address(yearnV2Mock), true
        );

        executeOneLineMulticall(address(adapter), callData);

        expectBalance(Tokens.DAI, creditAccount, initialDAIbalance - DAI_EXCHANGE_AMOUNT);

        expectBalance(yvDAI, creditAccount, (DAI_EXCHANGE_AMOUNT * WAD) / PRICE_PER_SHARE);

        expectAllowance(Tokens.DAI, creditAccount, address(yearnV2Mock), 1);

        expectTokenIsEnabled(yvDAI, true);

        expectSafeAllowance(address(yearnV2Mock));
    }

    //
    // WITHDRAW
    //

    /// @dev [AYV2-7]: withdraw works for user as expected
    function test_AYV2_07_withdraw_works_for_user_as_expected() public {
        setUp();

        (address creditAccount, uint256 yAmount) = _openYVDaiTestCreditAccount();

        bytes memory expectedCallData = abi.encodeWithSignature("withdraw(uint256)", yAmount - 1);

        expectMulticallStackCalls(
            address(adapter), address(yearnV2Mock), USER, expectedCallData, token, address(yearnV2Mock), false
        );

        executeOneLineMulticall(address(adapter), abi.encodeWithSignature("withdraw()"));

        expectBalance(Tokens.DAI, creditAccount, ((yAmount - 1) * PRICE_PER_SHARE) / WAD + 1);

        expectBalance(yvDAI, creditAccount, 1);

        // There is not need to approve yVault to itself, so nothing in terms of allowance should be done
        expectAllowance(yvDAI, creditAccount, address(yearnV2Mock), 0);

        expectTokenIsEnabled(yvDAI, false);
        expectTokenIsEnabled(Tokens.DAI, true);

        expectSafeAllowance(address(yearnV2Mock));
    }

    /// @dev [AYV2-8]: withdraw(uint256) works for user as expected
    function test_AYV2_08_withdraw_uint256_works_for_user_as_expected() public {
        setUp();
        (address creditAccount, uint256 yAmount) = _openYVDaiTestCreditAccount();

        expectAllowance(yvDAI, creditAccount, address(yearnV2Mock), 0);

        uint256 amount = yAmount / 2;

        bytes memory expectedCallData = abi.encodeWithSignature("withdraw(uint256)", amount);

        expectMulticallStackCalls(
            address(adapter), address(yearnV2Mock), USER, expectedCallData, token, address(yearnV2Mock), false
        );

        executeOneLineMulticall(address(adapter), abi.encodeWithSignature("withdraw(uint256)", amount));

        expectBalance(Tokens.DAI, creditAccount, ((amount) * PRICE_PER_SHARE) / WAD + 1);

        // +1 cause it keeps from deposit there
        expectBalance(yvDAI, creditAccount, yAmount - amount);

        // There is not need to approve yVault to itself, so nothing in terms of allowance should be done
        expectAllowance(yvDAI, creditAccount, address(yearnV2Mock), 0);

        expectTokenIsEnabled(Tokens.DAI, true);

        expectSafeAllowance(address(yearnV2Mock));
    }

    /// @dev [AYV2-9]: withdraw(uint256,address) works for user as expected
    function test_AYV2_09_withdraw_uint256_address_works_for_user_as_expected() public {
        setUp();
        (address creditAccount, uint256 yAmount) = _openYVDaiTestCreditAccount();

        expectAllowance(yvDAI, creditAccount, address(yearnV2Mock), 0);

        uint256 amount = yAmount / 2;

        bytes memory expectedCallData = abi.encodeWithSignature("withdraw(uint256)", amount);

        expectMulticallStackCalls(
            address(adapter), address(yearnV2Mock), USER, expectedCallData, token, address(yearnV2Mock), false
        );

        executeOneLineMulticall(
            address(adapter), abi.encodeWithSignature("withdraw(uint256,address)", amount, address(0))
        );

        expectBalance(Tokens.DAI, creditAccount, ((amount) * PRICE_PER_SHARE) / WAD + 1);

        // +1 cause it keeps from deposit there
        expectBalance(yvDAI, creditAccount, yAmount - amount);

        // There is not need to approve yVault to itself, so nothing in terms of allowance should be done
        expectAllowance(yvDAI, creditAccount, address(yearnV2Mock), 0);

        expectTokenIsEnabled(Tokens.DAI, true);

        expectSafeAllowance(address(yearnV2Mock));
    }

    /// @dev [AYV2-10]: withdraw(uint256,address,uint256) works for user as expected
    function test_AYV2_10_withdraw_uint256_address_uint256_works_for_user_as_expected() public {
        setUp();
        (address creditAccount, uint256 yAmount) = _openYVDaiTestCreditAccount();

        expectAllowance(yvDAI, creditAccount, address(yearnV2Mock), 0);

        uint256 amount = yAmount / 2;

        bytes memory expectedCallData =
            abi.encodeWithSignature("withdraw(uint256,address,uint256)", amount, creditAccount, 1);

        expectMulticallStackCalls(
            address(adapter), address(yearnV2Mock), USER, expectedCallData, token, address(yearnV2Mock), false
        );

        executeOneLineMulticall(
            address(adapter), abi.encodeWithSignature("withdraw(uint256,address,uint256)", amount, address(0), 1)
        );

        expectBalance(Tokens.DAI, creditAccount, ((amount) * PRICE_PER_SHARE) / WAD + 1);

        // +1 cause it keeps from deposit there
        expectBalance(yvDAI, creditAccount, yAmount - amount);

        // There is not need to approve yVault to itself, so nothing in terms of allowance should be done
        expectAllowance(yvDAI, creditAccount, address(yearnV2Mock), 0);

        expectTokenIsEnabled(Tokens.DAI, true);

        expectSafeAllowance(address(yearnV2Mock));
    }

    /// @dev [AYV2-11]: withdraw(uint256, address, uin256) passes maxLoss to target
    function test_AYV2_11_withdraw_correctly_passes_maxLoss() public {
        (, uint256 yAmount) = _openYVDaiTestCreditAccount();

        uint256 amount = yAmount / 2;

        evm.expectRevert(bytes("Loss too big"));
        executeOneLineMulticall(
            address(adapter), abi.encodeWithSignature("withdraw(uint256,address,uint256)", amount, address(0), 2)
        );
    }
}
