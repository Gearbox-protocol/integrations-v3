// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ICreditManagerV2, ICreditManagerV2Exceptions } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";

import { TokenIsNotAddedToCreditManagerException } from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

import { WstETHV1Adapter } from "../../../adapters/lido/WstETHV1.sol";
import { WstETHV1Mock } from "../../mocks/integrations/WstETHV1Mock.sol";
import { WstETHPriceFeed } from "../../../oracles/lido/WstETHPriceFeed.sol";
import { IwstETH } from "../../../integrations/lido/IwstETH.sol";

// TEST
import "../../lib/constants.sol";
import { Tokens } from "../../suites/TokensTestSuite.sol";

import { AdapterTestHelper } from "../AdapterTestHelper.sol";
import { ERC20Mock } from "@gearbox-protocol/core-v2/contracts/test/mocks/token/ERC20Mock.sol";
import { StringUtils } from "@gearbox-protocol/core-v2/contracts/test/lib/StringUtils.sol";

uint256 constant STETH_PER_TOKEN = (110 * WAD) / 100;

/// @title WstETHV1AdapterTest
/// @notice Designed for unit test purposes only
contract WstETHV1AdapterTest is DSTest, AdapterTestHelper {
    using StringUtils for string;
    WstETHV1Adapter public adapter;
    WstETHV1Mock public wstETHMock;
    address public stETH;

    function setUp() public {
        _setUp(Tokens.STETH);

        stETH = tokenTestSuite.addressOf(Tokens.STETH);

        wstETHMock = new WstETHV1Mock(stETH);
        wstETHMock.setStEthPerToken(STETH_PER_TOKEN);

        evm.startPrank(CONFIGURATOR);

        cft.priceOracle().addPriceFeed(
            address(wstETHMock),
            address(
                new WstETHPriceFeed(
                    address(cft.addressProvider()),
                    address(wstETHMock),
                    cft.priceOracle().priceFeeds(stETH)
                )
            )
        );

        creditConfigurator.addCollateralToken(address(wstETHMock), 8300);

        adapter = new WstETHV1Adapter(
            address(creditManager),
            address(wstETHMock)
        );

        creditConfigurator.allowContract(address(wstETHMock), address(adapter));

        evm.stopPrank();
        tokenTestSuite.mint(Tokens.WETH, USER, 10 * WETH_ACCOUNT_AMOUNT);

        evm.label(address(adapter), "ADAPTER");
        evm.label(address(stETH), "STETH");
        evm.label(address(wstETHMock), "WSTETH_MOCK");
    }

    //
    // HELPERS
    //

    function _openStETHTestCreditAccount(bool wrap)
        internal
        returns (address creditAccount, uint256 amount)
    {
        uint256 initialStETHbalance;
        (creditAccount, initialStETHbalance) = _openTestCreditAccount();

        if (wrap) {
            evm.prank(USER);
            adapter.wrapAll();

            amount = (((initialStETHbalance - 1) * WAD) / STETH_PER_TOKEN);
            expectBalance(Tokens.STETH, creditAccount, 1);
            expectBalance(address(wstETHMock), creditAccount, amount);

            expectTokenIsEnabled(Tokens.STETH, false);
            expectTokenIsEnabled(address(wstETHMock), true);
        } else {
            amount = initialStETHbalance;

            expectBalance(Tokens.STETH, creditAccount, initialStETHbalance);
            expectBalance(address(wstETHMock), creditAccount, 0);

            expectTokenIsEnabled(Tokens.STETH, true);
            expectTokenIsEnabled(address(wstETHMock), false);
        }
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [AWSTV1-1]: constructor sets correct values
    function test_AWSTV1_01_constructor_sets_correct_values() public {
        assertEq(
            address(adapter.stETH()),
            tokenTestSuite.addressOf(Tokens.STETH),
            "Incorrect token"
        );

        assertEq(adapter.decimals(), IERC20Metadata(stETH).decimals());
        assertTrue(adapter.name().eq(wstETHMock.name()));
        assertTrue(adapter.symbol().eq(wstETHMock.symbol()));
    }

    /// @dev [AWSTV1-2]: constructor reverts if token is not allowed
    function test_AWSTV1_02_constructor_reverts_if_token_is_not_allowed()
        public
    {
        ERC20Mock forbiddenToken = new ERC20Mock("Forbid", "FBD", 18);

        WstETHV1Mock forbidWstETHV1Mock = new WstETHV1Mock(
            address(forbiddenToken)
        );

        evm.expectRevert(
            abi.encodeWithSelector(
                TokenIsNotAddedToCreditManagerException.selector,
                address(forbidWstETHV1Mock)
            )
        );
        new WstETHV1Adapter(
            address(creditManager),
            address(forbidWstETHV1Mock)
        );

        WstETHV1Mock notAllowedWstETHV1Mock = new WstETHV1Mock(
            tokenTestSuite.addressOf(Tokens.STETH)
        );
        evm.expectRevert(
            abi.encodeWithSelector(
                TokenIsNotAddedToCreditManagerException.selector,
                address(notAllowedWstETHV1Mock)
            )
        );
        new WstETHV1Adapter(
            address(creditManager),
            address(notAllowedWstETHV1Mock)
        );
    }

    /// @dev [AWSTV1-3]: wrap and unwrap reverts if uses has no account
    function test_AWSTV1_03_wrap_and_unwrap_if_uses_has_no_account() public {
        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.wrapAll();

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.wrap(1000);

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.unwrapAll();

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.unwrap(1000);
    }

    // //
    // // WRAP
    // //

    /// @dev [AWSTV1-4]: wrapAll works for user as expected
    function test_AWSTV1_04_wrapAll_works_for_user_as_expected() public {
        // j == 0: wrapAll
        // j == 1: wrap(balance)
        for (uint256 j = 0; j < 2; ++j) {
            for (uint256 m = 0; m < 2; m++) {
                bool multicall = m != 0;

                setUp();
                (
                    address creditAccount,
                    uint256 initialStETHbalance
                ) = _openStETHTestCreditAccount(false);

                expectAllowance(
                    Tokens.STETH,
                    creditAccount,
                    address(wstETHMock),
                    0
                );

                bytes memory expectedCallData = abi.encodeWithSelector(
                    IwstETH.wrap.selector,
                    initialStETHbalance - 1
                );

                if (multicall) {
                    expectMulticallStackCalls(
                        address(adapter),
                        address(wstETHMock),
                        USER,
                        expectedCallData,
                        stETH,
                        address(wstETHMock),
                        true,
                        true
                    );

                    executeOneLineMulticall(
                        address(adapter),
                        j == 0
                            ? abi.encodeWithSelector(
                                WstETHV1Adapter.wrapAll.selector
                            )
                            : abi.encodeWithSelector(
                                WstETHV1Adapter.wrap.selector,
                                initialStETHbalance
                            )
                    );
                } else {
                    expectFastCheckStackCalls(
                        address(adapter),
                        address(wstETHMock),
                        USER,
                        expectedCallData,
                        stETH,
                        address(wstETHMock),
                        true,
                        true
                    );
                    evm.prank(USER);
                    if (j == 0) {
                        adapter.wrapAll();
                    } else {
                        adapter.wrap(initialStETHbalance);
                    }
                }
                expectBalance(Tokens.STETH, creditAccount, 1);

                expectBalance(
                    address(wstETHMock),
                    creditAccount,
                    ((initialStETHbalance - 1) * WAD) / STETH_PER_TOKEN
                );

                expectAllowance(
                    Tokens.STETH,
                    creditAccount,
                    address(wstETHMock),
                    1
                );

                expectTokenIsEnabled(Tokens.STETH, false);
                expectTokenIsEnabled(address(wstETHMock), true);

                expectSafeAllowance(address(wstETHMock));
            }
        }
    }

    /// @dev [AWSTV1-5]: wrap works for user as expected
    function test_AWSTV1_05_wrap_uint256_works_for_user_as_expected() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();
            (
                address creditAccount,
                uint256 initialStETHbalance
            ) = _openStETHTestCreditAccount(false);

            expectAllowance(
                Tokens.STETH,
                creditAccount,
                address(wstETHMock),
                0
            );

            bytes memory expectedCallData = abi.encodeWithSelector(
                IwstETH.wrap.selector,
                WETH_EXCHANGE_AMOUNT
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(wstETHMock),
                    USER,
                    expectedCallData,
                    stETH,
                    address(wstETHMock),
                    true,
                    true
                );

                executeOneLineMulticall(address(adapter), expectedCallData);
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(wstETHMock),
                    USER,
                    expectedCallData,
                    stETH,
                    address(wstETHMock),
                    true,
                    true
                );

                evm.prank(USER);
                adapter.wrap(WETH_EXCHANGE_AMOUNT);
            }
            expectBalance(
                Tokens.STETH,
                creditAccount,
                initialStETHbalance - WETH_EXCHANGE_AMOUNT
            );

            expectBalance(
                address(wstETHMock),
                creditAccount,
                (WETH_EXCHANGE_AMOUNT * WAD) / STETH_PER_TOKEN
            );

            expectAllowance(
                Tokens.STETH,
                creditAccount,
                address(wstETHMock),
                1
            );

            expectTokenIsEnabled(address(wstETHMock), true);

            expectSafeAllowance(address(wstETHMock));
        }
    }

    //
    // UNWRAP
    //

    /// @dev [AWSTV1-6]: unwrapAll works for user as expected
    function test_AWSTV1_06_unwrapAll_works_for_user_as_expected() public {
        // j == 0: wrapAll
        // j == 1: wrap(balance)
        for (uint256 j = 0; j < 2; ++j) {
            for (uint256 m = 0; m < 2; m++) {
                bool multicall = m != 0;

                setUp();

                (
                    address creditAccount,
                    uint256 initialWstETHamount
                ) = _openStETHTestCreditAccount(true);

                bytes memory expectedCallData = abi.encodeWithSelector(
                    IwstETH.unwrap.selector,
                    initialWstETHamount - 1
                );

                if (multicall) {
                    expectMulticallStackCalls(
                        address(adapter),
                        address(wstETHMock),
                        USER,
                        expectedCallData,
                        stETH,
                        address(wstETHMock),
                        true,
                        false
                    );

                    executeOneLineMulticall(
                        address(adapter),
                        (j == 0)
                            ? abi.encodeWithSelector(
                                WstETHV1Adapter.unwrapAll.selector
                            )
                            : abi.encodeWithSelector(
                                WstETHV1Adapter.unwrap.selector,
                                initialWstETHamount
                            )
                    );
                } else {
                    expectFastCheckStackCalls(
                        address(adapter),
                        address(wstETHMock),
                        USER,
                        expectedCallData,
                        address(wstETHMock),
                        stETH,
                        true,
                        false
                    );

                    evm.prank(USER);
                    if (j == 0) {
                        adapter.unwrapAll();
                    } else {
                        adapter.unwrap(initialWstETHamount);
                    }
                }

                expectBalance(
                    Tokens.STETH,
                    creditAccount,
                    ((initialWstETHamount - 1) * STETH_PER_TOKEN) / WAD + 1
                );

                expectBalance(address(wstETHMock), creditAccount, 1);

                // There is not need to approve yVault to itself, so nothing in terms of allowance should be done
                expectAllowance(
                    address(wstETHMock),
                    creditAccount,
                    address(wstETHMock),
                    0
                );

                expectTokenIsEnabled(address(wstETHMock), false);
                expectTokenIsEnabled(Tokens.STETH, true);

                expectSafeAllowance(address(wstETHMock));
            }
        }
    }

    /// @dev [AWSTV1-7]: unwrap works for user as expected
    function test_AWSTV1_07_unwrap_uint256_works_for_user_as_expected() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();
            (
                address creditAccount,
                uint256 wstETHamount
            ) = _openStETHTestCreditAccount(true);

            expectAllowance(
                address(wstETHMock),
                creditAccount,
                address(wstETHMock),
                0
            );

            uint256 amount = wstETHamount / 2;

            bytes memory expectedCallData = abi.encodeWithSelector(
                IwstETH.unwrap.selector,
                amount
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(wstETHMock),
                    USER,
                    expectedCallData,
                    stETH,
                    address(wstETHMock),
                    true,
                    false
                );

                executeOneLineMulticall(address(adapter), expectedCallData);
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(wstETHMock),
                    USER,
                    expectedCallData,
                    address(wstETHMock),
                    stETH,
                    true,
                    false
                );

                evm.prank(USER);
                adapter.unwrap(amount);
            }

            expectBalance(
                Tokens.STETH,
                creditAccount,
                ((amount) * STETH_PER_TOKEN) / WAD + 1
            );

            // +1 cause it keeps from deposit there
            expectBalance(
                address(wstETHMock),
                creditAccount,
                wstETHamount - amount
            );

            // There is not need to approve yVault to itself, so nothing in terms of allowance should be done
            expectAllowance(
                address(wstETHMock),
                creditAccount,
                address(wstETHMock),
                0
            );

            expectTokenIsEnabled(Tokens.STETH, true);

            expectSafeAllowance(address(wstETHMock));
        }
    }

    // //
    // //
    // //  GETTERS
    // //
    // //

    /// @dev [AWSTV1-8]: Adapter getWstETHByStETH() is consistent with Yearn vault
    function test_AWSTV1_08_adapter_getWstETHByStETH_consistent(uint256 amount)
        public
    {
        evm.assume(amount < 10**55);
        assertEq(
            adapter.getWstETHByStETH(amount),
            wstETHMock.getWstETHByStETH(amount)
        );

        assertEq(
            adapter.getStETHByWstETH(amount),
            wstETHMock.getStETHByWstETH(amount)
        );
    }

    /// @dev [AWSTV1-9]: Adapter pricePerShare() is consistent with Yearn vault
    function test_AWSTV1_09_adapter_pricePerShare_consistent() public {
        assertEq(adapter.stEthPerToken(), wstETHMock.stEthPerToken());

        assertEq(adapter.tokensPerStEth(), wstETHMock.tokensPerStEth());
    }

    /// @dev [AWSTV1-10]: Adapter allowance() is consistent with Yearn vault
    function test_AWSTV1_10_adapter_allowance_consistent() public {
        evm.prank(USER);
        creditFacade.openCreditAccount(WETH_ACCOUNT_AMOUNT, USER, 100, 0);

        evm.prank(address(creditFacade));
        creditManager.approveCreditAccount(
            USER,
            DUMB_ADDRESS,
            address(wstETHMock),
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
            wstETHMock.allowance(creditAccount, DUMB_ADDRESS),
            "Inconsistent allowance"
        );
    }

    /// @dev [AWSTV1-11]: Adapter balanceOf() and totalSupply() are consistent with Yearn vault
    function test_AWSTV1_11_adapter_balanceOf_totalSupply_consistent() public {
        evm.startPrank(USER);
        creditFacade.openCreditAccount(WETH_ACCOUNT_AMOUNT, USER, 100, 0);

        address creditAccount = creditManager.getCreditAccountOrRevert(USER);

        tokenTestSuite.mint(Tokens.STETH, creditAccount, WETH_ACCOUNT_AMOUNT);

        adapter.wrap(WETH_ACCOUNT_AMOUNT);

        evm.stopPrank();

        assertGt(adapter.balanceOf(creditAccount), 0);

        assertEq(
            adapter.balanceOf(creditAccount),
            wstETHMock.balanceOf(creditAccount)
        );
        assertEq(adapter.totalSupply(), wstETHMock.totalSupply());
    }
}
