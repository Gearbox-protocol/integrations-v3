// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ICreditManagerV2, ICreditManagerV2Exceptions } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";

import { YearnV2Adapter } from "../../../adapters/yearn/YearnV2.sol";

import { YearnV2Mock } from "../../mocks/integrations/YearnV2Mock.sol";

import { Tokens } from "../../suites/TokensTestSuite.sol";
import { YearnPriceFeed } from "../../../oracles/yearn/YearnPriceFeed.sol";

// TEST
import "../../lib/constants.sol";

import { AdapterTestHelper } from "../AdapterTestHelper.sol";
import { ERC20Mock } from "@gearbox-protocol/core-v2/contracts/test/mocks/token/ERC20Mock.sol";

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

        creditConfigurator.allowContract(
            address(yearnV2Mock),
            address(adapter)
        );

        evm.stopPrank();
        tokenTestSuite.mint(Tokens.DAI, USER, 10 * DAI_ACCOUNT_AMOUNT);

        evm.label(address(adapter), "ADAPTER");
        evm.label(address(yearnV2Mock), "YEARN_MOCK");
    }

    //
    // HELPERS
    //

    function _openYVDaiTestCreditAccount()
        internal
        returns (address creditAccount, uint256 yAmount)
    {
        uint256 initialDAIbalance;
        (creditAccount, initialDAIbalance) = _openTestCreditAccount();

        yAmount = (((initialDAIbalance - 1) * WAD) / PRICE_PER_SHARE);

        evm.prank(USER);
        adapter.deposit();

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
        assertEq(
            address(adapter.token()),
            tokenTestSuite.addressOf(Tokens.DAI),
            "Incorrect token"
        );
    }

    /// @dev [AYV2-2]: constructor reverts if token is not allowed
    function test_AYV2_02_constructor_reverts_if_token_is_not_allowed() public {
        ERC20Mock forbiddenToken = new ERC20Mock("Forbid", "FBD", 18);

        YearnV2Mock forbidYearnV2Mock = new YearnV2Mock(
            address(forbiddenToken)
        );

        evm.expectRevert(
            abi.encodeWithSelector(
                TokenIsNotInAllowedList.selector,
                address(forbiddenToken)
            )
        );
        new YearnV2Adapter(address(creditManager), address(forbidYearnV2Mock));

        YearnV2Mock notAllowedYearnV2Mock = new YearnV2Mock(
            tokenTestSuite.addressOf(Tokens.DAI)
        );

        evm.expectRevert(
            abi.encodeWithSelector(
                TokenIsNotInAllowedList.selector,
                address(notAllowedYearnV2Mock)
            )
        );

        new YearnV2Adapter(
            address(creditManager),
            address(notAllowedYearnV2Mock)
        );
    }

    /// @dev [AYV2-3]: depost(*) and witdraw(*) reverts if uses has no account
    function test_AYV2_03_deposit_and_withdraw_if_uses_has_no_account() public {
        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.deposit();

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.deposit(1000);

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.deposit(1000, address(0));

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.withdraw();

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.withdraw(1000);

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.withdraw(1000, address(0));

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.withdraw(1000, address(0), 2);
    }

    /// @dev [AYV2-4]: deposit works for user as expected
    function test_AYV2_04_deposit_works_for_user_as_expected() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();
            (
                address creditAccount,
                uint256 initialDAIbalance
            ) = _openTestCreditAccount();

            expectAllowance(Tokens.DAI, creditAccount, address(yearnV2Mock), 0);

            bytes memory expectedCallData = abi.encodeWithSignature(
                "deposit(uint256)",
                initialDAIbalance - 1
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(yearnV2Mock),
                    USER,
                    expectedCallData,
                    token,
                    address(yearnV2Mock),
                    true,
                    true
                );

                executeOneLineMulticall(
                    address(adapter),
                    abi.encodeWithSignature("deposit()")
                );
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(yearnV2Mock),
                    USER,
                    expectedCallData,
                    token,
                    address(yearnV2Mock),
                    true,
                    true
                );

                evm.prank(USER);
                adapter.deposit();
            }
            expectBalance(Tokens.DAI, creditAccount, 1);

            expectBalance(
                yvDAI,
                creditAccount,
                ((initialDAIbalance - 1) * WAD) / PRICE_PER_SHARE
            );

            expectAllowance(Tokens.DAI, creditAccount, address(yearnV2Mock), 1);

            expectTokenIsEnabled(Tokens.DAI, false);
            expectTokenIsEnabled(yvDAI, true);

            expectSafeAllowance(address(yearnV2Mock));
        }
    }

    /// @dev [AYV2-5]: deposit(uint256) works for user as expected
    function test_AYV2_05_deposit_uint256_works_for_user_as_expected() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();
            (
                address creditAccount,
                uint256 initialDAIbalance
            ) = _openTestCreditAccount();

            expectAllowance(Tokens.DAI, creditAccount, address(yearnV2Mock), 0);

            bytes memory expectedCallData = abi.encodeWithSignature(
                "deposit(uint256)",
                DAI_EXCHANGE_AMOUNT
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(yearnV2Mock),
                    USER,
                    expectedCallData,
                    token,
                    address(yearnV2Mock),
                    true,
                    true
                );

                executeOneLineMulticall(
                    address(adapter),
                    abi.encodeWithSignature(
                        "deposit(uint256)",
                        DAI_EXCHANGE_AMOUNT
                    )
                );
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(yearnV2Mock),
                    USER,
                    expectedCallData,
                    token,
                    address(yearnV2Mock),
                    true,
                    true
                );

                evm.prank(USER);
                adapter.deposit(DAI_EXCHANGE_AMOUNT);
            }
            expectBalance(
                Tokens.DAI,
                creditAccount,
                initialDAIbalance - DAI_EXCHANGE_AMOUNT
            );

            expectBalance(
                yvDAI,
                creditAccount,
                (DAI_EXCHANGE_AMOUNT * WAD) / PRICE_PER_SHARE
            );

            expectAllowance(Tokens.DAI, creditAccount, address(yearnV2Mock), 1);

            expectTokenIsEnabled(yvDAI, true);

            expectSafeAllowance(address(yearnV2Mock));
        }
    }

    /// @dev [AYV2-6]: deposit(uint256, address) works for user as expected
    function test_AYV2_06_deposit_uint256_address_works_for_user_as_expected()
        public
    {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();
            (
                address creditAccount,
                uint256 initialDAIbalance
            ) = _openTestCreditAccount();

            expectAllowance(Tokens.DAI, creditAccount, address(yearnV2Mock), 0);

            bytes memory expectedCallData = abi.encodeWithSignature(
                "deposit(uint256)",
                DAI_EXCHANGE_AMOUNT
            );

            if (multicall) {
                bytes memory callData = abi.encodeWithSignature(
                    "deposit(uint256,address)",
                    DAI_EXCHANGE_AMOUNT,
                    address(0)
                );

                executeOneLineMulticall(address(adapter), callData);
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(yearnV2Mock),
                    USER,
                    expectedCallData,
                    token,
                    address(yearnV2Mock),
                    true,
                    true
                );

                evm.prank(USER);
                adapter.deposit(DAI_EXCHANGE_AMOUNT, address(0));
            }

            expectBalance(
                Tokens.DAI,
                creditAccount,
                initialDAIbalance - DAI_EXCHANGE_AMOUNT
            );

            expectBalance(
                yvDAI,
                creditAccount,
                (DAI_EXCHANGE_AMOUNT * WAD) / PRICE_PER_SHARE
            );

            expectAllowance(Tokens.DAI, creditAccount, address(yearnV2Mock), 1);

            expectTokenIsEnabled(yvDAI, true);

            expectSafeAllowance(address(yearnV2Mock));
        }
    }

    //
    // WITHDRAW
    //

    /// @dev [AYV2-7]: withdraw works for user as expected
    function test_AYV2_07_withdraw_works_for_user_as_expected() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();

            (
                address creditAccount,
                uint256 yAmount
            ) = _openYVDaiTestCreditAccount();

            bytes memory expectedCallData = abi.encodeWithSignature(
                "withdraw(uint256)",
                yAmount - 1
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(yearnV2Mock),
                    USER,
                    expectedCallData,
                    token,
                    address(yearnV2Mock),
                    true,
                    false
                );

                executeOneLineMulticall(
                    address(adapter),
                    abi.encodeWithSignature("withdraw()")
                );
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(yearnV2Mock),
                    USER,
                    expectedCallData,
                    address(yearnV2Mock),
                    token,
                    true,
                    false
                );

                evm.prank(USER);
                adapter.withdraw();
            }

            expectBalance(
                Tokens.DAI,
                creditAccount,
                ((yAmount - 1) * PRICE_PER_SHARE) / WAD + 1
            );

            expectBalance(yvDAI, creditAccount, 1);

            // There is not need to approve yVault to itself, so nothing in terms of allowance should be done
            expectAllowance(yvDAI, creditAccount, address(yearnV2Mock), 0);

            expectTokenIsEnabled(yvDAI, false);
            expectTokenIsEnabled(Tokens.DAI, true);

            expectSafeAllowance(address(yearnV2Mock));
        }
    }

    /// @dev [AYV2-8]: withdraw(uint256) works for user as expected
    function test_AYV2_08_withdraw_uint256_works_for_user_as_expected() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();
            (
                address creditAccount,
                uint256 yAmount
            ) = _openYVDaiTestCreditAccount();

            expectAllowance(yvDAI, creditAccount, address(yearnV2Mock), 0);

            uint256 amount = yAmount / 2;

            bytes memory expectedCallData = abi.encodeWithSignature(
                "withdraw(uint256)",
                amount
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(yearnV2Mock),
                    USER,
                    expectedCallData,
                    token,
                    address(yearnV2Mock),
                    true,
                    false
                );

                executeOneLineMulticall(
                    address(adapter),
                    abi.encodeWithSignature("withdraw(uint256)", amount)
                );
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(yearnV2Mock),
                    USER,
                    expectedCallData,
                    address(yearnV2Mock),
                    token,
                    true,
                    false
                );

                evm.prank(USER);
                adapter.withdraw(amount);
            }

            expectBalance(
                Tokens.DAI,
                creditAccount,
                ((amount) * PRICE_PER_SHARE) / WAD + 1
            );

            // +1 cause it keeps from deposit there
            expectBalance(yvDAI, creditAccount, yAmount - amount);

            // There is not need to approve yVault to itself, so nothing in terms of allowance should be done
            expectAllowance(yvDAI, creditAccount, address(yearnV2Mock), 0);

            expectTokenIsEnabled(Tokens.DAI, true);

            expectSafeAllowance(address(yearnV2Mock));
        }
    }

    /// @dev [AYV2-9]: withdraw(uint256,address) works for user as expected
    function test_AYV2_09_withdraw_uint256_address_works_for_user_as_expected()
        public
    {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();
            (
                address creditAccount,
                uint256 yAmount
            ) = _openYVDaiTestCreditAccount();

            expectAllowance(yvDAI, creditAccount, address(yearnV2Mock), 0);

            uint256 amount = yAmount / 2;

            bytes memory expectedCallData = abi.encodeWithSignature(
                "withdraw(uint256)",
                amount
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(yearnV2Mock),
                    USER,
                    expectedCallData,
                    token,
                    address(yearnV2Mock),
                    true,
                    false
                );

                executeOneLineMulticall(
                    address(adapter),
                    abi.encodeWithSignature(
                        "withdraw(uint256,address)",
                        amount,
                        address(0)
                    )
                );
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(yearnV2Mock),
                    USER,
                    expectedCallData,
                    address(yearnV2Mock),
                    token,
                    true,
                    false
                );

                evm.prank(USER);
                adapter.withdraw(amount, address(0));
            }
            expectBalance(
                Tokens.DAI,
                creditAccount,
                ((amount) * PRICE_PER_SHARE) / WAD + 1
            );

            // +1 cause it keeps from deposit there
            expectBalance(yvDAI, creditAccount, yAmount - amount);

            // There is not need to approve yVault to itself, so nothing in terms of allowance should be done
            expectAllowance(yvDAI, creditAccount, address(yearnV2Mock), 0);

            expectTokenIsEnabled(Tokens.DAI, true);

            expectSafeAllowance(address(yearnV2Mock));
        }
    }

    /// @dev [AYV2-10]: withdraw(uint256,address,uint256) works for user as expected
    function test_AYV2_10_withdraw_uint256_address_uint256_works_for_user_as_expected()
        public
    {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();
            (
                address creditAccount,
                uint256 yAmount
            ) = _openYVDaiTestCreditAccount();

            expectAllowance(yvDAI, creditAccount, address(yearnV2Mock), 0);

            uint256 amount = yAmount / 2;

            bytes memory expectedCallData = abi.encodeWithSignature(
                "withdraw(uint256,address,uint256)",
                amount,
                creditAccount,
                1
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(yearnV2Mock),
                    USER,
                    expectedCallData,
                    token,
                    address(yearnV2Mock),
                    true,
                    false
                );

                executeOneLineMulticall(
                    address(adapter),
                    abi.encodeWithSignature(
                        "withdraw(uint256,address,uint256)",
                        amount,
                        address(0),
                        1
                    )
                );
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(yearnV2Mock),
                    USER,
                    expectedCallData,
                    address(yearnV2Mock),
                    token,
                    true,
                    false
                );

                evm.prank(USER);

                adapter.withdraw(amount, address(0), 1);
            }

            expectBalance(
                Tokens.DAI,
                creditAccount,
                ((amount) * PRICE_PER_SHARE) / WAD + 1
            );

            // +1 cause it keeps from deposit there
            expectBalance(yvDAI, creditAccount, yAmount - amount);

            // There is not need to approve yVault to itself, so nothing in terms of allowance should be done
            expectAllowance(yvDAI, creditAccount, address(yearnV2Mock), 0);

            expectTokenIsEnabled(Tokens.DAI, true);

            expectSafeAllowance(address(yearnV2Mock));
        }
    }

    /// @dev [AYV2-11]: withdraw(uint256, address, uin256) passes maxLoss to target
    function test_AYV2_11_withdraw_correctly_passes_maxLoss() public {
        (, uint256 yAmount) = _openYVDaiTestCreditAccount();

        uint256 amount = yAmount / 2;

        evm.expectRevert(bytes("Loss too big"));

        evm.prank(USER);
        adapter.withdraw(amount, address(0), 2);
    }

    //
    //
    //  GETTERS
    //
    //

    /// @dev [AYV2-12]: Adapter pricePerShare() is consistent with Yearn vault
    function test_AYV2_12_adapter_pricePerShare_consistent() public {
        assertEq(adapter.pricePerShare(), yearnV2Mock.pricePerShare());
    }

    /// @dev [AYV2-13]: Adapter name() is consistent with Yearn vault
    function test_AYV2_13_adapter_name_consistent() public {
        assertEq(adapter.name(), yearnV2Mock.name());
    }

    /// @dev [AYV2-14]: Adapter symbol() is consistent with Yearn vault
    function test_AYV2_14_adapter_symbol_consistent() public {
        assertEq(adapter.symbol(), yearnV2Mock.symbol());
    }

    /// @dev [AYV2-15]: Adapter decimals() is consistent with Yearn vault
    function test_AYV2_15_adapter_decimals_consistent() public {
        assertEq(adapter.decimals(), yearnV2Mock.decimals());
    }

    /// @dev [AYV2-16]: Adapter allowance() is consistent with Yearn vault
    function test_AYV2_16_adapter_allowance_consistent() public {
        evm.prank(USER);
        creditFacade.openCreditAccount(DAI_ACCOUNT_AMOUNT, USER, 100, 0);

        evm.prank(address(creditFacade));
        creditManager.approveCreditAccount(
            USER,
            DUMB_ADDRESS,
            address(yearnV2Mock),
            2000
        );

        address creditAccount = creditManager.getCreditAccountOrRevert(USER);

        assertEq(
            adapter.allowance(creditAccount, DUMB_ADDRESS),
            2000,
            "Different adapter allowance"
        );
        assertEq(
            adapter.allowance(creditAccount, DUMB_ADDRESS),
            yearnV2Mock.allowance(creditAccount, DUMB_ADDRESS),
            "Inconsistent allowance"
        );
    }

    /// @dev [AYV2-17]: Adapter balanceOf() and totalSupply() are consistent with Yearn vault
    function test_AYV2_17_adapter_balanceOf_totalSupply_consistent() public {
        evm.startPrank(USER);
        creditFacade.openCreditAccount(DAI_ACCOUNT_AMOUNT, USER, 100, 0);

        address creditAccount = creditManager.getCreditAccountOrRevert(USER);

        tokenTestSuite.mint(Tokens.DAI, creditAccount, DAI_ACCOUNT_AMOUNT);

        adapter.deposit(DAI_ACCOUNT_AMOUNT);

        evm.stopPrank();

        assertGt(adapter.balanceOf(creditAccount), 0);

        assertEq(
            adapter.balanceOf(creditAccount),
            yearnV2Mock.balanceOf(creditAccount)
        );
        assertEq(adapter.totalSupply(), yearnV2Mock.totalSupply());
    }
}
