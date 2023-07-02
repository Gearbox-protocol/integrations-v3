// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {IUniswapV2Router02} from "../../../../integrations/uniswap/IUniswapV2Router02.sol";
import {UniswapV2Adapter} from "../../../../adapters/uniswap/UniswapV2.sol";
import {IUniswapV2Adapter, IUniswapV2AdapterExceptions} from "../../../../interfaces/uniswap/IUniswapV2Adapter.sol";
import {UniswapV2Mock} from "../../../mocks/integrations/UniswapV2Mock.sol";

import {Tokens} from "../../../suites/TokensTestSuite.sol";

// TEST
import "../../../lib/constants.sol";
import {AdapterTestHelper} from "../AdapterTestHelper.sol";

/// @title UniswapV2AdapterTest
/// @notice Designed for unit test purposes only
contract UniswapV2AdapterTest is AdapterTestHelper, IUniswapV2AdapterExceptions {
    IUniswapV2Adapter public adapter;
    UniswapV2Mock public uniswapMock;
    uint256 public deadline;

    function setUp() public {
        _setUp();

        uniswapMock = new UniswapV2Mock();

        uniswapMock.setRate(
            tokenTestSuite.addressOf(Tokens.DAI), tokenTestSuite.addressOf(Tokens.WETH), RAY / DAI_WETH_RATE
        );

        uniswapMock.setRate(tokenTestSuite.addressOf(Tokens.DAI), tokenTestSuite.addressOf(Tokens.USDC), RAY);

        uniswapMock.setRate(tokenTestSuite.addressOf(Tokens.USDC), tokenTestSuite.addressOf(Tokens.USDT), RAY);

        uniswapMock.setRate(
            tokenTestSuite.addressOf(Tokens.USDT), tokenTestSuite.addressOf(Tokens.WETH), RAY / DAI_WETH_RATE
        );

        tokenTestSuite.mint(Tokens.WETH, address(uniswapMock), (2 * DAI_ACCOUNT_AMOUNT) / DAI_WETH_RATE);

        address[] memory connectors = new address[](2);

        connectors[0] = tokenTestSuite.addressOf(Tokens.USDC);
        connectors[1] = tokenTestSuite.addressOf(Tokens.USDT);

        adapter = new UniswapV2Adapter(
            address(CreditManagerV3),
            address(uniswapMock),
            connectors
        );

        vm.prank(CONFIGURATOR);
        CreditConfiguratorV3.allowContract(address(uniswapMock), address(adapter));

        vm.label(address(adapter), "ADAPTER");
        vm.label(address(uniswapMock), "UNISWAP_MOCK");

        deadline = _getUniswapDeadline();
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [AUV2-1]: swap reverts if uses has no account
    function test_AUV2_01_swap_reverts_if_user_has_no_account() public {
        address[] memory dumbPath;

        vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(
            address(adapter), abi.encodeCall(adapter.swapTokensForExactTokens, (0, 0, dumbPath, address(0), 0))
        );

        vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(
            address(adapter), abi.encodeCall(adapter.swapExactTokensForTokens, (0, 0, dumbPath, address(0), 0))
        );

        vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
        executeOneLineMulticall(address(adapter), abi.encodeCall(adapter.swapAllTokensForTokens, (0, dumbPath, 0)));
    }

    /// @dev [AUV2-2]: swapTokensForExactTokens works for user as expected
    function test_AUV2_02_swapTokensForExactTokens_works_for_user_as_expected() public {
        setUp();

        address[] memory path = new address[](2);
        path[0] = CreditManagerV3.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.WETH);

        (address creditAccount, uint256 initialDAIbalance) = _openTestCreditAccount();

        expectAllowance(path[0], creditAccount, address(uniswapMock), 0);

        bytes memory expectedCallData = abi.encodeCall(
            IUniswapV2Router02.swapTokensForExactTokens,
            (
                DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE / 2,
                DAI_EXCHANGE_AMOUNT,
                path,
                address(creditAccount), // adapter should change recepient from address(0) to creditAccount
                deadline
            )
        );

        expectMulticallStackCalls(
            address(adapter), address(uniswapMock), USER, expectedCallData, path[0], path[1], true
        );

        // MULTICALL
        executeOneLineMulticall(
            address(adapter),
            abi.encodeCall(
                adapter.swapTokensForExactTokens,
                (
                    DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE / 2,
                    DAI_EXCHANGE_AMOUNT,
                    path,
                    address(0), // adapter should change recepient from address(0) to creditAccount
                    deadline
                )
            )
        );

        expectBalance(Tokens.DAI, creditAccount, initialDAIbalance - ((DAI_EXCHANGE_AMOUNT / 2) * 1000) / 997);

        expectBalance(Tokens.WETH, creditAccount, DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE / 2);

        expectAllowance(CreditManagerV3.underlying(), creditAccount, address(uniswapMock), 1);

        expectTokenIsEnabled(Tokens.WETH, true);
    }

    /// @dev [AUV2-3]: swapExactTokensForTokens works for user as expected
    function test_AUV2_03_swapExactTokensForTokens_works_for_user_as_expected() public {
        setUp();
        address[] memory path = new address[](2);
        path[0] = CreditManagerV3.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.WETH);

        (address creditAccount, uint256 initialDAIbalance) = _openTestCreditAccount();

        expectAllowance(path[0], creditAccount, address(uniswapMock), 0);

        bytes memory expectedCallData = abi.encodeCall(
            IUniswapV2Router02.swapExactTokensForTokens,
            (
                DAI_EXCHANGE_AMOUNT,
                0,
                path,
                address(creditAccount), // adapter should change recepient from address(0) to creditAccount
                deadline
            )
        );

        expectMulticallStackCalls(
            address(adapter), address(uniswapMock), USER, expectedCallData, path[0], path[1], true
        );

        // MULTICALL
        executeOneLineMulticall(
            address(adapter),
            abi.encodeCall(
                adapter.swapExactTokensForTokens,
                (
                    DAI_EXCHANGE_AMOUNT,
                    0,
                    path,
                    address(0), // adapter should change recepient from address(0) to creditAccount
                    deadline
                )
            )
        );

        expectBalance(Tokens.DAI, creditAccount, initialDAIbalance - DAI_EXCHANGE_AMOUNT);

        expectBalance(Tokens.WETH, creditAccount, ((DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE) * 997) / 1000);

        expectAllowance(path[0], creditAccount, address(uniswapMock), 1);

        expectTokenIsEnabled(path[1], true);
    }

    /// @dev [AUV2-4]: swapAllTokensForTokens works for user as expected
    function test_AUV2_04_swapAllTokensForTokens_works_for_user_as_expected() public {
        setUp();
        address[] memory path = new address[](2);
        path[0] = CreditManagerV3.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.WETH);

        (address creditAccount, uint256 initialDAIbalance) = _openTestCreditAccount();

        expectAllowance(path[0], creditAccount, address(uniswapMock), 0);

        bytes memory expectedCallData = abi.encodeCall(
            IUniswapV2Router02.swapExactTokensForTokens,
            (
                initialDAIbalance - 1,
                (((initialDAIbalance - 1) / DAI_WETH_RATE) * 997) / 1000,
                path,
                address(creditAccount),
                deadline
            )
        );

        expectMulticallStackCalls(
            address(adapter), address(uniswapMock), USER, expectedCallData, path[0], path[1], true
        );

        // MULTICALL
        executeOneLineMulticall(
            address(adapter),
            abi.encodeCall(
                IUniswapV2Adapter.swapAllTokensForTokens,
                (((RAY / DAI_WETH_RATE) * 997) / 1000, path, _getUniswapDeadline())
            )
        );

        expectBalance(Tokens.DAI, creditAccount, 1);

        expectBalance(Tokens.WETH, creditAccount, (((initialDAIbalance - 1) / DAI_WETH_RATE) * 997) / 1000);

        expectAllowance(path[0], creditAccount, address(uniswapMock), 1);

        expectTokenIsEnabled(path[0], false);
        expectTokenIsEnabled(path[1], true);
    }

    /// @dev [AUV2-5]: Path validity checks are correct
    function test_AUV2_05_path_validity_checks_are_correct() public {
        _openTestCreditAccount();

        address[] memory path = new address[](5);
        path[0] = CreditManagerV3.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.USDC);
        path[2] = tokenTestSuite.addressOf(Tokens.USDT);
        path[3] = tokenTestSuite.addressOf(Tokens.LINK);
        path[4] = tokenTestSuite.addressOf(Tokens.WETH);

        vm.expectRevert(InvalidPathException.selector);
        executeOneLineMulticall(
            address(adapter),
            abi.encodeCall(adapter.swapExactTokensForTokens, (DAI_EXCHANGE_AMOUNT, 0, path, address(0), deadline))
        );

        vm.expectRevert(InvalidPathException.selector);
        executeOneLineMulticall(
            address(adapter),
            abi.encodeCall(
                adapter.swapTokensForExactTokens,
                (DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE / 2, DAI_EXCHANGE_AMOUNT, path, address(0), deadline)
            )
        );

        vm.expectRevert(InvalidPathException.selector);
        executeOneLineMulticall(
            address(adapter),
            abi.encodeCall(
                adapter.swapAllTokensForTokens, (((RAY / DAI_WETH_RATE) * 997) / 1000, path, _getUniswapDeadline())
            )
        );

        path = new address[](4);
        path[0] = CreditManagerV3.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.USDC);
        path[2] = tokenTestSuite.addressOf(Tokens.LINK);
        path[3] = tokenTestSuite.addressOf(Tokens.WETH);

        vm.expectRevert(InvalidPathException.selector);
        executeOneLineMulticall(
            address(adapter),
            abi.encodeCall(adapter.swapExactTokensForTokens, (DAI_EXCHANGE_AMOUNT, 0, path, address(0), deadline))
        );

        vm.expectRevert(InvalidPathException.selector);
        executeOneLineMulticall(
            address(adapter),
            abi.encodeCall(adapter.swapExactTokensForTokens, (DAI_EXCHANGE_AMOUNT, 0, path, address(0), deadline))
        );

        path = new address[](4);
        path[0] = CreditManagerV3.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.LINK);
        path[2] = tokenTestSuite.addressOf(Tokens.USDT);
        path[3] = tokenTestSuite.addressOf(Tokens.WETH);

        vm.expectRevert(InvalidPathException.selector);
        executeOneLineMulticall(
            address(adapter),
            abi.encodeCall(adapter.swapExactTokensForTokens, (DAI_EXCHANGE_AMOUNT, 0, path, address(0), deadline))
        );

        path = new address[](4);
        path[0] = CreditManagerV3.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.USDC);
        path[2] = tokenTestSuite.addressOf(Tokens.USDT);
        path[3] = tokenTestSuite.addressOf(Tokens.WETH);

        executeOneLineMulticall(
            address(adapter),
            abi.encodeCall(adapter.swapExactTokensForTokens, (DAI_EXCHANGE_AMOUNT, 0, path, address(0), deadline))
        );
    }
}
