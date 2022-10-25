// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ICreditManagerV2Exceptions } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";

import { BytesLib } from "../../../integrations/uniswap/BytesLib.sol";

import { ISwapRouter } from "../../../integrations/uniswap/IUniswapV3.sol";
import { UniswapV3Adapter } from "../../../adapters/uniswap/UniswapV3.sol";
import { IUniswapV3Adapter } from "../../../interfaces/uniswap/IUniswapV3Adapter.sol";
import { UniswapV3Mock } from "../../mocks/integrations/UniswapV3Mock.sol";

import { Tokens } from "../../suites/TokensTestSuite.sol";

// TEST
import "../../lib/constants.sol";

import { AdapterTestHelper } from "../AdapterTestHelper.sol";

/// @title UniswapV3AdapterTest
/// @notice Designed for unit test purposes only
contract UniswapV3AdapterTest is DSTest, AdapterTestHelper {
    using BytesLib for bytes;

    IUniswapV3Adapter public adapter;
    UniswapV3Mock public uniswapMock;
    uint256 public deadline;

    function setUp() public {
        _setUp();
        uniswapMock = new UniswapV3Mock();

        uniswapMock.setRate(
            tokenTestSuite.addressOf(Tokens.WETH),
            tokenTestSuite.addressOf(Tokens.DAI),
            DAI_WETH_RATE * RAY
        );

        tokenTestSuite.mint(
            Tokens.WETH,
            address(uniswapMock),
            (2 * DAI_ACCOUNT_AMOUNT) / DAI_WETH_RATE
        );

        adapter = new UniswapV3Adapter(
            address(creditManager),
            address(uniswapMock)
        );

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(
            address(uniswapMock),
            address(adapter)
        );

        evm.label(address(adapter), "ADAPTER");
        evm.label(address(uniswapMock), "UNISWAP_V3_MOCK");

        deadline = _getUniswapDeadline();
    }

    ///
    /// HELPERS
    ///

    function _getExactInputSingleParams()
        internal
        view
        returns (ISwapRouter.ExactInputSingleParams memory params)
    {
        params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenTestSuite.addressOf(Tokens.DAI),
            tokenOut: tokenTestSuite.addressOf(Tokens.WETH),
            fee: 3000,
            recipient: USER,
            deadline: deadline,
            amountIn: DAI_EXCHANGE_AMOUNT,
            amountOutMinimum: ((DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE) * 997) /
                1000,
            sqrtPriceLimitX96: 0
        });
    }

    function _getExactInputParams()
        internal
        view
        returns (ISwapRouter.ExactInputParams memory params)
    {
        address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
        address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

        params = ISwapRouter.ExactInputParams({
            path: bytes(abi.encodePacked(tokenIn))
                .concat(bytes(abi.encodePacked(uint24(3000))))
                .concat(bytes(abi.encodePacked(tokenOut))),
            recipient: USER,
            deadline: deadline,
            amountIn: DAI_EXCHANGE_AMOUNT,
            amountOutMinimum: ((DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE) * 997) /
                1000
        });
    }

    function _getAllInputSingleParams()
        internal
        view
        returns (IUniswapV3Adapter.ExactAllInputSingleParams memory params)
    {
        params = IUniswapV3Adapter.ExactAllInputSingleParams({
            tokenIn: tokenTestSuite.addressOf(Tokens.DAI),
            tokenOut: tokenTestSuite.addressOf(Tokens.WETH),
            fee: 3000,
            deadline: deadline,
            rateMinRAY: ((RAY / DAI_WETH_RATE) * 997) / 1000,
            sqrtPriceLimitX96: 0
        });
    }

    function _getAllInputParams()
        internal
        view
        returns (IUniswapV3Adapter.ExactAllInputParams memory params)
    {
        address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
        address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

        params = IUniswapV3Adapter.ExactAllInputParams({
            path: bytes(abi.encodePacked(tokenIn))
                .concat(bytes(abi.encodePacked(uint24(3000))))
                .concat(bytes(abi.encodePacked(tokenOut))),
            deadline: deadline,
            rateMinRAY: ((RAY / DAI_WETH_RATE) * 997) / 1000
        });
    }

    function _getExactOutputSingleParams()
        internal
        view
        returns (IUniswapV3Adapter.ExactOutputSingleParams memory params)
    {
        params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: tokenTestSuite.addressOf(Tokens.DAI),
            tokenOut: tokenTestSuite.addressOf(Tokens.WETH),
            fee: 3000,
            recipient: USER,
            deadline: deadline,
            amountOut: DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE / 2,
            amountInMaximum: DAI_EXCHANGE_AMOUNT,
            sqrtPriceLimitX96: 0
        });
    }

    function _getExactOutputParams()
        internal
        view
        returns (IUniswapV3Adapter.ExactOutputParams memory params)
    {
        address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
        address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

        params = ISwapRouter.ExactOutputParams({
            path: bytes(abi.encodePacked(tokenOut))
                .concat(bytes(abi.encodePacked(uint24(3000))))
                .concat(bytes(abi.encodePacked(tokenIn))),
            recipient: USER,
            deadline: deadline,
            amountOut: DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE / 2,
            amountInMaximum: DAI_EXCHANGE_AMOUNT
        });
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [AUV3-1]: swap reverts if uses has no account
    function test_AUV3_01_swap_reverts_if_uses_has_no_account() public {
        ISwapRouter.ExactInputSingleParams
            memory exactInputSingleParams = _getExactInputSingleParams();
        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.exactInputSingle(exactInputSingleParams);

        ISwapRouter.ExactInputParams
            memory exactInputParams = _getExactInputParams();
        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.exactInput(exactInputParams);

        IUniswapV3Adapter.ExactAllInputSingleParams
            memory exactAllInputSingleParams = _getAllInputSingleParams();

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.exactAllInputSingle(exactAllInputSingleParams);

        IUniswapV3Adapter.ExactAllInputParams
            memory exactAllInputParams = _getAllInputParams();

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.exactAllInput(exactAllInputParams);

        IUniswapV3Adapter.ExactOutputSingleParams
            memory exactOutputSingleParams = _getExactOutputSingleParams();

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.exactOutputSingle(exactOutputSingleParams);

        IUniswapV3Adapter.ExactOutputParams
            memory exactOutputParams = _getExactOutputParams();
        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapter.exactOutput(exactOutputParams);
    }

    //
    // USER INTERACTION
    //

    /// @dev [AUV3-2]: exactInputSingle works for user as expected
    function test_AUV3_02_exactInputSingle_works_for_user_as_expected() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();

            ISwapRouter.ExactInputSingleParams
                memory exactInputSingleParams = _getExactInputSingleParams();

            (
                address creditAccount,
                uint256 initialDAIbalance
            ) = _openTestCreditAccount();

            expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 0);

            exactInputSingleParams.recipient = creditAccount;

            bytes memory expectedCallData = abi.encodeWithSelector(
                ISwapRouter.exactInputSingle.selector,
                exactInputSingleParams
            );

            exactInputSingleParams.recipient = address(0);

            bytes memory callData = abi.encodeWithSelector(
                ISwapRouter.exactInputSingle.selector,
                exactInputSingleParams
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    exactInputSingleParams.tokenIn,
                    exactInputSingleParams.tokenOut,
                    false
                );

                // MULTICALL
                executeOneLineMulticall(address(adapter), callData);
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    exactInputSingleParams.tokenIn,
                    exactInputSingleParams.tokenOut,
                    false
                );

                evm.prank(USER);
                adapter.exactInputSingle(exactInputSingleParams);
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
                Tokens.DAI,
                creditAccount,
                address(uniswapMock),
                type(uint256).max
            );

            expectTokenIsEnabled(Tokens.WETH, true);
        }
    }

    /// @dev [AUV3-3]: exactAllInputSingle works for user as expected
    function test_AUV3_03_exactAllInputSingle_works_for_user_as_expected()
        public
    {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();

            IUniswapV3Adapter.ExactAllInputSingleParams
                memory exactAllInputSingleParams = _getAllInputSingleParams();

            (
                address creditAccount,
                uint256 initialDAIbalance
            ) = _openTestCreditAccount();

            expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 0);

            uint256 amountIn = initialDAIbalance - 1;

            bytes memory expectedcCallData = abi.encodeWithSelector(
                ISwapRouter.exactInputSingle.selector,
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: tokenTestSuite.addressOf(Tokens.DAI),
                    tokenOut: tokenTestSuite.addressOf(Tokens.WETH),
                    fee: 3000,
                    recipient: creditAccount,
                    deadline: exactAllInputSingleParams.deadline,
                    amountIn: amountIn,
                    amountOutMinimum: ((amountIn / DAI_WETH_RATE) * 997) / 1000,
                    sqrtPriceLimitX96: 0
                })
            );

            if (multicall) {
                bytes memory callData = abi.encodeWithSelector(
                    IUniswapV3Adapter.exactAllInputSingle.selector,
                    exactAllInputSingleParams
                );

                expectMulticallStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedcCallData,
                    exactAllInputSingleParams.tokenIn,
                    exactAllInputSingleParams.tokenOut,
                    false
                );

                // MULTICALL
                executeOneLineMulticall(address(adapter), callData);
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedcCallData,
                    exactAllInputSingleParams.tokenIn,
                    exactAllInputSingleParams.tokenOut,
                    false
                );

                evm.prank(USER);
                adapter.exactAllInputSingle(exactAllInputSingleParams);
            }

            expectBalance(Tokens.DAI, creditAccount, 1);

            expectBalance(
                Tokens.WETH,
                creditAccount,
                (((initialDAIbalance - 1) / DAI_WETH_RATE) *
                    (1_000_000 - 3000)) / 1_000_000
            );

            expectAllowance(
                Tokens.DAI,
                creditAccount,
                address(uniswapMock),
                type(uint256).max
            );

            expectTokenIsEnabled(Tokens.DAI, false);
            expectTokenIsEnabled(Tokens.WETH, true);
        }
    }

    /// @dev [AUV3-4]: exactInput works for user as expected
    function test_AUV3_04_exactInput_works_for_user_as_expected() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();

            ISwapRouter.ExactInputParams
                memory exactInputParams = _getExactInputParams();

            (
                address creditAccount,
                uint256 initialDAIbalance
            ) = _openTestCreditAccount();

            expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 0);

            bytes memory callData = abi.encodeWithSelector(
                ISwapRouter.exactInput.selector,
                exactInputParams
            );

            exactInputParams.recipient = creditAccount;

            bytes memory expectedCallData = abi.encodeWithSelector(
                ISwapRouter.exactInput.selector,
                exactInputParams
            );

            address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
            address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    tokenIn,
                    tokenOut,
                    false
                );
                // MULTICALL
                executeOneLineMulticall(address(adapter), callData);
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    tokenIn,
                    tokenOut,
                    false
                );

                exactInputParams.recipient = address(0);

                evm.prank(USER);
                adapter.exactInput(exactInputParams);
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
                Tokens.DAI,
                creditAccount,
                address(uniswapMock),
                type(uint256).max
            );

            expectTokenIsEnabled(Tokens.WETH, true);
        }
    }

    /// @dev [AUV3-5]: exactAllInput works for user as expected
    function test_AUV3_05_exactAllInput_works_for_user_as_expected() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;
            setUp();

            IUniswapV3Adapter.ExactAllInputParams
                memory exactAllInputParams = _getAllInputParams();

            (
                address creditAccount,
                uint256 initialDAIbalance
            ) = _openTestCreditAccount();

            expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 0);

            address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
            address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

            uint256 amountIn = initialDAIbalance - 1;

            bytes memory expectedCallData = abi.encodeWithSelector(
                ISwapRouter.exactInput.selector,
                ISwapRouter.ExactInputParams({
                    path: bytes(abi.encodePacked(tokenIn))
                        .concat(bytes(abi.encodePacked(uint24(3000))))
                        .concat(bytes(abi.encodePacked(tokenOut))),
                    recipient: creditAccount,
                    deadline: exactAllInputParams.deadline,
                    amountIn: amountIn,
                    amountOutMinimum: ((amountIn / DAI_WETH_RATE) * 997) / 1000
                })
            );

            if (multicall) {
                bytes memory callData = abi.encodeWithSelector(
                    IUniswapV3Adapter.exactAllInput.selector,
                    exactAllInputParams
                );

                expectMulticallStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    tokenIn,
                    tokenOut,
                    false
                );

                // MULTICALL
                executeOneLineMulticall(address(adapter), callData);
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    tokenIn,
                    tokenOut,
                    false
                );

                evm.prank(USER);
                adapter.exactAllInput(exactAllInputParams);
            }

            expectBalance(Tokens.DAI, creditAccount, 1);

            expectBalance(
                Tokens.WETH,
                creditAccount,
                (((initialDAIbalance - 1) / DAI_WETH_RATE) *
                    (1_000_000 - 3000)) / 1_000_000
            );

            expectAllowance(
                Tokens.DAI,
                creditAccount,
                address(uniswapMock),
                type(uint256).max
            );

            expectTokenIsEnabled(Tokens.DAI, false);
            expectTokenIsEnabled(Tokens.WETH, true);
        }
    }

    /// @dev [AUV3-6]: exactOutputSingle works for user as expected
    function test_AUV3_06_exactOutputSingle_works_for_user_as_expected()
        public
    {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;
            setUp();

            ISwapRouter.ExactOutputSingleParams
                memory exactOutputSingleParams = _getExactOutputSingleParams();

            (
                address creditAccount,
                uint256 initialDAIbalance
            ) = _openTestCreditAccount();

            expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 0);

            bytes memory callData = abi.encodeWithSelector(
                ISwapRouter.exactOutputSingle.selector,
                exactOutputSingleParams
            );

            exactOutputSingleParams.recipient = creditAccount;

            bytes memory expectedCallData = abi.encodeWithSelector(
                ISwapRouter.exactOutputSingle.selector,
                exactOutputSingleParams
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    exactOutputSingleParams.tokenIn,
                    exactOutputSingleParams.tokenOut,
                    false
                );
                // MULTICALL
                executeOneLineMulticall(address(adapter), callData);
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    exactOutputSingleParams.tokenIn,
                    exactOutputSingleParams.tokenOut,
                    false
                );

                exactOutputSingleParams.recipient = address(0);

                evm.prank(USER);
                adapter.exactOutputSingle(exactOutputSingleParams);
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
                Tokens.DAI,
                creditAccount,
                address(uniswapMock),
                type(uint256).max
            );

            expectTokenIsEnabled(Tokens.WETH, true);
        }
    }

    /// @dev [AUV3-7]: exactOutput works for user as expected
    function test_AUV3_07_exactOutput_works_for_user_as_expected() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;
            setUp();

            ISwapRouter.ExactOutputParams
                memory exactOutputParams = _getExactOutputParams();

            (
                address creditAccount,
                uint256 initialDAIbalance
            ) = _openTestCreditAccount();

            expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 0);

            bytes memory callData = abi.encodeWithSelector(
                ISwapRouter.exactOutput.selector,
                exactOutputParams
            );

            exactOutputParams.recipient = creditAccount;

            bytes memory expectedCallData = abi.encodeWithSelector(
                ISwapRouter.exactOutput.selector,
                exactOutputParams
            );

            address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
            address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    tokenIn,
                    tokenOut,
                    false
                );
                // MULTICALL
                executeOneLineMulticall(address(adapter), callData);
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(uniswapMock),
                    USER,
                    expectedCallData,
                    tokenIn,
                    tokenOut,
                    false
                );

                exactOutputParams.recipient = address(0);
                evm.prank(USER);
                adapter.exactOutput(exactOutputParams);
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
                Tokens.DAI,
                creditAccount,
                address(uniswapMock),
                type(uint256).max
            );

            expectTokenIsEnabled(Tokens.WETH, true);
        }
    }

    /// @dev [AUV3-8]: UniswapV3 adapter can't be exploited with an incorrectly-formed path
    function test_AUV3_08_exactOutput_cannot_be_exploited_with_tailored_path_parameter()
        public
    {
        address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
        address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

        ISwapRouter.ExactOutputParams
            memory exactOutputParams = _getExactOutputParams();

        exactOutputParams.path = exactOutputParams.path.concat(
            abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDC))
        );

        (
            address creditAccount,
            uint256 initialDAIbalance
        ) = _openTestCreditAccount();

        expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 0);

        exactOutputParams.recipient = creditAccount;

        bytes memory expectedCallData = abi.encodeWithSelector(
            ISwapRouter.exactOutput.selector,
            exactOutputParams
        );

        expectFastCheckStackCalls(
            address(adapter),
            address(uniswapMock),
            USER,
            expectedCallData,
            tokenIn,
            tokenOut,
            false
        );

        exactOutputParams.recipient = address(0);
        evm.prank(USER);
        adapter.exactOutput(exactOutputParams);

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
            Tokens.DAI,
            creditAccount,
            address(uniswapMock),
            type(uint256).max
        );

        expectAllowance(Tokens.USDC, creditAccount, address(uniswapMock), 0);

        expectTokenIsEnabled(Tokens.WETH, true);
        expectTokenIsEnabled(Tokens.USDC, false);
    }
}
