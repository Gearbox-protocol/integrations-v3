// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ICreditManagerV2Exceptions } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";

import { IUniswapV2Router02 } from "../../../integrations/uniswap/IUniswapV2Router02.sol";
import { UniswapV2Adapter } from "../../../adapters/uniswap/UniswapV2.sol";
import { IUniswapV2Adapter, IUniswapV2AdapterExceptions } from "../../../interfaces/uniswap/IUniswapV2Adapter.sol";
import { UniswapV2Mock } from "../../mocks/integrations/UniswapV2Mock.sol";

import { Tokens } from "../../suites/TokensTestSuite.sol";

// TEST
import "../../lib/constants.sol";
import { AdapterTestHelper } from "../AdapterTestHelper.sol";

/// @title UniswapV2AdapterTest
/// @notice Designed for unit test purposes only
contract UniswapV2AdapterTest is
    AdapterTestHelper,
    IUniswapV2AdapterExceptions
{
    IUniswapV2Adapter public adapter;
    UniswapV2Mock public uniswapMock;
    uint256 public deadline;

    function setUp() public {
        _setUp();

        uniswapMock = new UniswapV2Mock();

        uniswapMock.setRate(
            tokenTestSuite.addressOf(Tokens.DAI),
            tokenTestSuite.addressOf(Tokens.WETH),
            RAY / DAI_WETH_RATE
        );

        uniswapMock.setRate(
            tokenTestSuite.addressOf(Tokens.DAI),
            tokenTestSuite.addressOf(Tokens.USDC),
            RAY
        );

        uniswapMock.setRate(
            tokenTestSuite.addressOf(Tokens.USDC),
            tokenTestSuite.addressOf(Tokens.USDT),
            RAY
        );

        uniswapMock.setRate(
            tokenTestSuite.addressOf(Tokens.USDT),
            tokenTestSuite.addressOf(Tokens.WETH),
            RAY / DAI_WETH_RATE
        );

        tokenTestSuite.mint(
            Tokens.WETH,
            address(uniswapMock),
            (2 * DAI_ACCOUNT_AMOUNT) / DAI_WETH_RATE
        );

        address[] memory connectors = new address[](2);

        connectors[0] = tokenTestSuite.addressOf(Tokens.USDC);
        connectors[1] = tokenTestSuite.addressOf(Tokens.USDT);

        adapter = new UniswapV2Adapter(
            address(creditManager),
            address(uniswapMock),
            connectors
        );

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(
            address(uniswapMock),
            address(adapter)
        );

        evm.label(address(adapter), "ADAPTER");
        evm.label(address(uniswapMock), "UNISWAP_MOCK");

        deadline = _getUniswapDeadline();
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [AUV2-1]: swap reverts if uses has no account
    function test_AUV2_01_swap_reverts_if_uses_has_no_account() public {
        address[] memory dumbPath;

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.swapTokensForExactTokens(0, 0, dumbPath, address(0), 0);

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.swapExactTokensForTokens(0, 0, dumbPath, address(0), 0);

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.swapAllTokensForTokens(0, dumbPath, 0);
    }

    /// @dev [AUV2-2]: swapTokensForExactTokens works for user as expected
    function test_AUV2_02_swapTokensForExactTokens_works_for_user_as_expected()
        public
    {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();

            address[] memory path = new address[](2);
            path[0] = creditManager.underlying();
            path[1] = tokenTestSuite.addressOf(Tokens.WETH);

            (
                address creditAccount,
                uint256 initialDAIbalance
            ) = _openTestCreditAccount();

            expectAllowance(path[0], creditAccount, address(uniswapMock), 0);

            bytes memory expectedCallData = abi.encodeWithSelector(
                IUniswapV2Router02.swapTokensForExactTokens.selector,
                DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE / 2,
                DAI_EXCHANGE_AMOUNT,
                path,
                address(creditAccount), // adapter should change recepient from address(0) to creditAccount
                deadline
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    path[0],
                    path[1],
                    false
                );

                // MULTICALL
                executeOneLineMulticall(
                    address(adapter),
                    abi.encodeWithSelector(
                        IUniswapV2Router02.swapTokensForExactTokens.selector,
                        DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE / 2,
                        DAI_EXCHANGE_AMOUNT,
                        path,
                        address(creditAccount), // adapter should change recepient from address(0) to creditAccount
                        deadline
                    )
                );
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    path[0],
                    path[1],
                    false
                );

                evm.prank(USER);
                adapter.swapTokensForExactTokens(
                    DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE / 2,
                    DAI_EXCHANGE_AMOUNT,
                    path,
                    address(0),
                    deadline
                );
            }

            expectBalance(
                Tokens.DAI,
                creditAccount,
                initialDAIbalance - ((DAI_EXCHANGE_AMOUNT / 2) * 1000) / 997
            );

            expectBalance(
                Tokens.WETH,
                creditAccount,
                DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE / 2
            );

            expectAllowance(
                creditManager.underlying(),
                creditAccount,
                address(uniswapMock),
                type(uint256).max
            );

            expectTokenIsEnabled(Tokens.WETH, true);
        }
    }

    /// @dev [AUV2-3]: swapExactTokensForTokens works for user as expected
    function test_AUV2_03_swapExactTokensForTokens_works_for_user_as_expected()
        public
    {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();
            address[] memory path = new address[](2);
            path[0] = creditManager.underlying();
            path[1] = tokenTestSuite.addressOf(Tokens.WETH);

            (
                address creditAccount,
                uint256 initialDAIbalance
            ) = _openTestCreditAccount();

            expectAllowance(path[0], creditAccount, address(uniswapMock), 0);

            bytes memory expectedCallData = abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForTokens.selector,
                DAI_EXCHANGE_AMOUNT,
                0,
                path,
                address(creditAccount), // adapter should change recepient from address(0) to creditAccount
                deadline
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    path[0],
                    path[1],
                    false
                );

                // MULTICALL
                executeOneLineMulticall(
                    address(adapter),
                    abi.encodeWithSelector(
                        IUniswapV2Router02.swapExactTokensForTokens.selector,
                        DAI_EXCHANGE_AMOUNT,
                        0,
                        path,
                        address(0), // adapter should change recepient from address(0) to creditAccount
                        deadline
                    )
                );
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    path[0],
                    path[1],
                    false
                );

                evm.prank(USER);
                adapter.swapExactTokensForTokens(
                    DAI_EXCHANGE_AMOUNT,
                    0,
                    path,
                    address(0),
                    deadline
                );
            }
            expectBalance(
                Tokens.DAI,
                creditAccount,
                initialDAIbalance - DAI_EXCHANGE_AMOUNT
            );

            expectBalance(
                Tokens.WETH,
                creditAccount,
                ((DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE) * 997) / 1000
            );

            expectAllowance(
                path[0],
                creditAccount,
                address(uniswapMock),
                type(uint256).max
            );

            expectTokenIsEnabled(path[1], true);
        }
    }

    /// @dev [AUV2-4]: swapAllTokensForTokens works for user as expected
    function test_AUV2_04_swapAllTokensForTokens_works_for_user_as_expected()
        public
    {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();
            address[] memory path = new address[](2);
            path[0] = creditManager.underlying();
            path[1] = tokenTestSuite.addressOf(Tokens.WETH);

            (
                address creditAccount,
                uint256 initialDAIbalance
            ) = _openTestCreditAccount();

            expectAllowance(path[0], creditAccount, address(uniswapMock), 0);

            bytes memory expectedCallData = abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForTokens.selector,
                initialDAIbalance - 1,
                (((initialDAIbalance - 1) / DAI_WETH_RATE) * 997) / 1000,
                path,
                address(creditAccount), // adapter should change recepient from address(0) to creditAccount
                deadline
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    path[0],
                    path[1],
                    false
                );

                // MULTICALL
                executeOneLineMulticall(
                    address(adapter),
                    abi.encodeWithSelector(
                        IUniswapV2Adapter.swapAllTokensForTokens.selector,
                        ((RAY / DAI_WETH_RATE) * 997) / 1000,
                        path,
                        _getUniswapDeadline()
                    )
                );
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    path[0],
                    path[1],
                    false
                );

                evm.prank(USER);
                adapter.swapAllTokensForTokens(
                    ((RAY / DAI_WETH_RATE) * 997) / 1000,
                    path,
                    _getUniswapDeadline()
                );
            }

            expectBalance(Tokens.DAI, creditAccount, 1);

            expectBalance(
                Tokens.WETH,
                creditAccount,
                (((initialDAIbalance - 1) / DAI_WETH_RATE) * 997) / 1000
            );

            expectAllowance(
                path[0],
                creditAccount,
                address(uniswapMock),
                type(uint256).max
            );

            expectTokenIsEnabled(path[0], false);
            expectTokenIsEnabled(path[1], true);
        }
    }

    //
    //
    //  GETTERS
    //
    ///

    /// @dev [AUV2-5]: Adapter quote() is consistent with router quote()
    function test_AUV2_05_adapter_quote_same_as_router(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public {
        address router = adapter.targetContract();
        assertEq(
            adapter.quote(amountA, reserveA, reserveB),
            IUniswapV2Router02(router).quote(amountA, reserveA, reserveB)
        );
    }

    /// @dev [AUV2-6]: Adapter getAmountOut() is consistent with router getAmountOut()
    function test_AUV2_06_adapter_getAmountOut_same_as_router(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public {
        address router = adapter.targetContract();
        assertEq(
            adapter.getAmountOut(amountIn, reserveIn, reserveOut),
            IUniswapV2Router02(router).getAmountOut(
                amountIn,
                reserveIn,
                reserveOut
            )
        );
    }

    /// @dev [AUV2-7]: Adapter getAmountIn() is consistent with router getAmountIn()
    function test_AUV2_07_adapter_getAmountIn_same_as_router(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public {
        address router = adapter.targetContract();
        assertEq(
            adapter.getAmountIn(amountOut, reserveIn, reserveOut),
            IUniswapV2Router02(router).getAmountIn(
                amountOut,
                reserveIn,
                reserveOut
            )
        );
    }

    /// @dev [AUV2-8]: Adapter getAmountsOut() is consistent with router getAmountsOut()
    function test_AUV2_08_adapter_getAmountsOut_same_as_router(uint256 amountIn)
        public
    {
        evm.assume(amountIn < 1e10 ether);

        address[] memory path = new address[](2);
        path[0] = creditManager.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.WETH);

        address router = adapter.targetContract();

        uint256[] memory amounts0 = adapter.getAmountsOut(amountIn, path);
        uint256[] memory amounts1 = IUniswapV2Router02(router).getAmountsOut(
            amountIn,
            path
        );

        assertEq(amounts0.length, amounts1.length);

        for (uint256 i = 0; i < amounts0.length; i++) {
            assertEq(amounts0[i], amounts1[i]);
        }
    }

    /// @dev [AUV2-9]: Adapter getAmountsIn() is consistent with router getAmountsIn()
    function test_AUV2_09_adapter_getAmountsIn_same_as_router(uint256 amountOut)
        public
    {
        evm.assume(amountOut < 1e10 ether);

        address[] memory path = new address[](2);
        path[0] = creditManager.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.WETH);

        address router = adapter.targetContract();

        uint256[] memory amounts0 = adapter.getAmountsIn(amountOut, path);
        uint256[] memory amounts1 = IUniswapV2Router02(router).getAmountsIn(
            amountOut,
            path
        );

        assertEq(amounts0.length, amounts1.length);

        for (uint256 i = 0; i < amounts0.length; i++) {
            assertEq(amounts0[i], amounts1[i]);
        }
    }

    /// @dev [AUV2-10]: Path validity checks are correct
    function test_AUV2_10_path_validity_checks_are_correct() public {
        _openTestCreditAccount();

        address[] memory path = new address[](5);
        path[0] = creditManager.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.USDC);
        path[2] = tokenTestSuite.addressOf(Tokens.USDT);
        path[3] = tokenTestSuite.addressOf(Tokens.LINK);
        path[4] = tokenTestSuite.addressOf(Tokens.WETH);

        evm.expectRevert(InvalidPathException.selector);
        evm.prank(USER);
        adapter.swapExactTokensForTokens(
            DAI_EXCHANGE_AMOUNT,
            0,
            path,
            address(0),
            deadline
        );

        evm.expectRevert(InvalidPathException.selector);
        evm.prank(USER);
        adapter.swapTokensForExactTokens(
            DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE / 2,
            DAI_EXCHANGE_AMOUNT,
            path,
            address(0),
            deadline
        );

        evm.expectRevert(InvalidPathException.selector);
        evm.prank(USER);
        adapter.swapAllTokensForTokens(
            ((RAY / DAI_WETH_RATE) * 997) / 1000,
            path,
            _getUniswapDeadline()
        );

        path = new address[](4);
        path[0] = creditManager.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.USDC);
        path[2] = tokenTestSuite.addressOf(Tokens.LINK);
        path[3] = tokenTestSuite.addressOf(Tokens.WETH);

        evm.expectRevert(InvalidPathException.selector);
        evm.prank(USER);
        adapter.swapExactTokensForTokens(
            DAI_EXCHANGE_AMOUNT,
            0,
            path,
            address(0),
            deadline
        );

        evm.expectRevert(InvalidPathException.selector);
        evm.prank(USER);
        adapter.swapExactTokensForTokens(
            DAI_EXCHANGE_AMOUNT,
            0,
            path,
            address(0),
            deadline
        );

        path = new address[](4);
        path[0] = creditManager.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.LINK);
        path[2] = tokenTestSuite.addressOf(Tokens.USDT);
        path[3] = tokenTestSuite.addressOf(Tokens.WETH);

        evm.expectRevert(InvalidPathException.selector);
        evm.prank(USER);
        adapter.swapExactTokensForTokens(
            DAI_EXCHANGE_AMOUNT,
            0,
            path,
            address(0),
            deadline
        );

        path = new address[](4);
        path[0] = creditManager.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.USDC);
        path[2] = tokenTestSuite.addressOf(Tokens.USDT);
        path[3] = tokenTestSuite.addressOf(Tokens.WETH);

        evm.prank(USER);
        adapter.swapExactTokensForTokens(
            DAI_EXCHANGE_AMOUNT,
            0,
            path,
            address(0),
            deadline
        );
    }
}
