// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {BytesLib} from "../../../../integrations/uniswap/BytesLib.sol";

import {ISwapRouter} from "../../../../integrations/uniswap/IUniswapV3.sol";
import {UniswapV3Adapter} from "../../../../adapters/uniswap/UniswapV3.sol";
import {
    IUniswapV3Adapter,
    IUniswapV3AdapterExceptions,
    IUniswapV3AdapterTypes
} from "../../../../interfaces/uniswap/IUniswapV3Adapter.sol";
import {UniswapV3Mock} from "../../../mocks/integrations/UniswapV3Mock.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";

// TEST
import "../../../lib/constants.sol";

import {AdapterTestHelper} from "../AdapterTestHelper.sol";

/// @title UniswapV3AdapterTest
/// @notice Designed for unit test purposes only
contract UniswapV3AdapterTest is Test, AdapterTestHelper, IUniswapV3AdapterTypes, IUniswapV3AdapterExceptions {
    using BytesLib for bytes;

    IUniswapV3Adapter public adapter;
    UniswapV3Mock public uniswapMock;
    uint256 public deadline;

    function setUp() public {
        _setUp();
        uniswapMock = new UniswapV3Mock();

        uniswapMock.setRate(
            tokenTestSuite.addressOf(Tokens.WETH), tokenTestSuite.addressOf(Tokens.DAI), DAI_WETH_RATE * RAY
        );

        uniswapMock.setRate(tokenTestSuite.addressOf(Tokens.DAI), tokenTestSuite.addressOf(Tokens.USDC), RAY);

        uniswapMock.setRate(
            tokenTestSuite.addressOf(Tokens.WETH), tokenTestSuite.addressOf(Tokens.USDC), DAI_WETH_RATE * RAY
        );

        uniswapMock.setRate(tokenTestSuite.addressOf(Tokens.USDC), tokenTestSuite.addressOf(Tokens.USDT), RAY);

        uniswapMock.setRate(
            tokenTestSuite.addressOf(Tokens.USDT), tokenTestSuite.addressOf(Tokens.WETH), RAY / DAI_WETH_RATE
        );

        tokenTestSuite.mint(Tokens.WETH, address(uniswapMock), (2 * DAI_ACCOUNT_AMOUNT) / DAI_WETH_RATE);

        adapter = new UniswapV3Adapter(address(creditManager), address(uniswapMock));

        vm.prank(CONFIGURATOR);
        creditConfigurator.allowAdapter(address(adapter));

        vm.label(address(adapter), "ADAPTER");
        vm.label(address(uniswapMock), "UNISWAP_V3_MOCK");

        deadline = _getUniswapDeadline();
    }

    ///
    /// HELPERS
    ///

    function _getExactInputSingleParams() internal view returns (ISwapRouter.ExactInputSingleParams memory params) {
        params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenTestSuite.addressOf(Tokens.DAI),
            tokenOut: tokenTestSuite.addressOf(Tokens.WETH),
            fee: 3000,
            recipient: USER,
            deadline: deadline,
            amountIn: DAI_EXCHANGE_AMOUNT,
            amountOutMinimum: ((DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE) * 997) / 1000,
            sqrtPriceLimitX96: 0
        });
    }

    function _getExactInputParams() internal view returns (ISwapRouter.ExactInputParams memory params) {
        address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
        address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

        params = ISwapRouter.ExactInputParams({
            path: bytes(abi.encodePacked(tokenIn)).concat(bytes(abi.encodePacked(uint24(3000)))).concat(
                bytes(abi.encodePacked(tokenOut))
                ),
            recipient: USER,
            deadline: deadline,
            amountIn: DAI_EXCHANGE_AMOUNT,
            amountOutMinimum: ((DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE) * 997) / 1000
        });
    }

    function _getAllInputSingleParams()
        internal
        view
        returns (IUniswapV3Adapter.ExactAllInputSingleParams memory params)
    {
        params = ExactAllInputSingleParams({
            tokenIn: tokenTestSuite.addressOf(Tokens.DAI),
            tokenOut: tokenTestSuite.addressOf(Tokens.WETH),
            fee: 3000,
            deadline: deadline,
            rateMinRAY: ((RAY / DAI_WETH_RATE) * 997) / 1000,
            sqrtPriceLimitX96: 0
        });
    }

    function _getAllInputParams() internal view returns (IUniswapV3Adapter.ExactAllInputParams memory params) {
        address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
        address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

        params = ExactAllInputParams({
            path: bytes(abi.encodePacked(tokenIn)).concat(bytes(abi.encodePacked(uint24(3000)))).concat(
                bytes(abi.encodePacked(tokenOut))
                ),
            deadline: deadline,
            rateMinRAY: ((RAY / DAI_WETH_RATE) * 997) / 1000
        });
    }

    function _getExactOutputSingleParams() internal view returns (ISwapRouter.ExactOutputSingleParams memory params) {
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

    function _getExactOutputParams() internal view returns (ISwapRouter.ExactOutputParams memory params) {
        address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
        address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

        params = ISwapRouter.ExactOutputParams({
            path: bytes(abi.encodePacked(tokenOut)).concat(bytes(abi.encodePacked(uint24(3000)))).concat(
                bytes(abi.encodePacked(tokenIn))
                ),
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

    // /// @dev [AUV3-1]: swap reverts if user has no account
    // function test_AUV3_01_swap_reverts_if_user_has_no_account() public {
    //     ISwapRouter.ExactInputSingleParams memory exactInputSingleParams = _getExactInputSingleParams();
    //     vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
    //     executeOneLineMulticall(
    //         creditAccount, address(adapter), abi.encodeCall(adapter.exactInputSingle, (exactInputSingleParams))
    //     );

    //     ISwapRouter.ExactInputParams memory exactInputParams = _getExactInputParams();
    //     vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
    //     executeOneLineMulticall(creditAccount, address(adapter), abi.encodeCall(adapter.exactInput, (exactInputParams)));

    //     IUniswapV3Adapter.ExactAllInputSingleParams memory exactAllInputSingleParams = _getAllInputSingleParams();

    //     vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
    //     executeOneLineMulticall(
    //         creditAccount, address(adapter), abi.encodeCall(adapter.exactAllInputSingle, (exactAllInputSingleParams))
    //     );

    //     IUniswapV3Adapter.ExactAllInputParams memory exactAllInputParams = _getAllInputParams();

    //     vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
    //     executeOneLineMulticall(
    //         creditAccount, address(adapter), abi.encodeCall(adapter.exactAllInput, (exactAllInputParams))
    //     );

    //     ISwapRouter.ExactOutputSingleParams memory exactOutputSingleParams = _getExactOutputSingleParams();

    //     vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
    //     executeOneLineMulticall(
    //         creditAccount, address(adapter), abi.encodeCall(adapter.exactOutputSingle, (exactOutputSingleParams))
    //     );

    //     ISwapRouter.ExactOutputParams memory exactOutputParams = _getExactOutputParams();
    //     vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
    //     executeOneLineMulticall(
    //         creditAccount, address(adapter), abi.encodeCall(adapter.exactOutput, (exactOutputParams))
    //     );
    // }

    //
    // USER INTERACTION
    //

    /// @dev [AUV3-2]: exactInputSingle works for user as expected
    function test_AUV3_02_exactInputSingle_works_for_user_as_expected() public {
        setUp();

        ISwapRouter.ExactInputSingleParams memory exactInputSingleParams = _getExactInputSingleParams();

        (address creditAccount, uint256 initialDAIbalance) = _openTestCreditAccount();

        expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 0);

        exactInputSingleParams.recipient = creditAccount;

        bytes memory expectedCallData = abi.encodeCall(ISwapRouter.exactInputSingle, (exactInputSingleParams));

        exactInputSingleParams.recipient = address(0);

        bytes memory callData = abi.encodeCall(adapter.exactInputSingle, (exactInputSingleParams));

        expectMulticallStackCalls(
            address(adapter),
            address(uniswapMock),
            USER,
            expectedCallData,
            exactInputSingleParams.tokenIn,
            exactInputSingleParams.tokenOut,
            true
        );

        // MULTICALL
        executeOneLineMulticall(creditAccount, address(adapter), callData);

        expectBalance(Tokens.DAI, creditAccount, initialDAIbalance - DAI_EXCHANGE_AMOUNT);

        expectBalance(Tokens.WETH, creditAccount, ((DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE) * 997) / 1000);

        expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 1);

        expectTokenIsEnabled(creditAccount, Tokens.WETH, true);
    }

    /// @dev [AUV3-3]: exactAllInputSingle works for user as expected
    function test_AUV3_03_exactAllInputSingle_works_for_user_as_expected() public {
        setUp();

        IUniswapV3Adapter.ExactAllInputSingleParams memory exactAllInputSingleParams = _getAllInputSingleParams();

        (address creditAccount, uint256 initialDAIbalance) = _openTestCreditAccount();

        expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 0);

        uint256 amountIn = initialDAIbalance - 1;

        bytes memory expectedCallData = abi.encodeCall(
            ISwapRouter.exactInputSingle,
            (
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
            )
        );

        bytes memory callData = abi.encodeCall(adapter.exactAllInputSingle, (exactAllInputSingleParams));

        expectMulticallStackCalls(
            address(adapter),
            address(uniswapMock),
            USER,
            expectedCallData,
            exactAllInputSingleParams.tokenIn,
            exactAllInputSingleParams.tokenOut,
            true
        );

        // MULTICALL
        executeOneLineMulticall(creditAccount, address(adapter), callData);

        expectBalance(Tokens.DAI, creditAccount, 1);

        expectBalance(
            Tokens.WETH, creditAccount, (((initialDAIbalance - 1) / DAI_WETH_RATE) * (1_000_000 - 3000)) / 1_000_000
        );

        expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 1);

        expectTokenIsEnabled(creditAccount, Tokens.DAI, false);
        expectTokenIsEnabled(creditAccount, Tokens.WETH, true);
    }

    /// @dev [AUV3-4]: exactInput works for user as expected
    function test_AUV3_04_exactInput_works_for_user_as_expected() public {
        setUp();

        ISwapRouter.ExactInputParams memory exactInputParams = _getExactInputParams();

        (address creditAccount, uint256 initialDAIbalance) = _openTestCreditAccount();

        expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 0);

        bytes memory callData = abi.encodeCall(adapter.exactInput, (exactInputParams));

        exactInputParams.recipient = creditAccount;

        bytes memory expectedCallData = abi.encodeCall(ISwapRouter.exactInput, (exactInputParams));

        address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
        address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

        expectMulticallStackCalls(
            address(adapter), address(uniswapMock), USER, expectedCallData, tokenIn, tokenOut, true
        );

        // MULTICALL
        executeOneLineMulticall(creditAccount, address(adapter), callData);

        expectBalance(Tokens.DAI, creditAccount, initialDAIbalance - DAI_EXCHANGE_AMOUNT);

        expectBalance(Tokens.WETH, creditAccount, ((DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE) * 997) / 1000);

        expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 1);

        expectTokenIsEnabled(creditAccount, Tokens.WETH, true);
    }

    /// @dev [AUV3-5]: exactAllInput works for user as expected
    function test_AUV3_05_exactAllInput_works_for_user_as_expected() public {
        setUp();

        IUniswapV3Adapter.ExactAllInputParams memory exactAllInputParams = _getAllInputParams();

        (address creditAccount, uint256 initialDAIbalance) = _openTestCreditAccount();

        expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 0);

        address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
        address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

        uint256 amountIn = initialDAIbalance - 1;

        bytes memory expectedCallData = abi.encodeCall(
            ISwapRouter.exactInput,
            (
                ISwapRouter.ExactInputParams({
                    path: bytes(abi.encodePacked(tokenIn)).concat(bytes(abi.encodePacked(uint24(3000)))).concat(
                        bytes(abi.encodePacked(tokenOut))
                        ),
                    recipient: creditAccount,
                    deadline: exactAllInputParams.deadline,
                    amountIn: amountIn,
                    amountOutMinimum: ((amountIn / DAI_WETH_RATE) * 997) / 1000
                })
            )
        );

        bytes memory callData = abi.encodeCall(adapter.exactAllInput, (exactAllInputParams));

        expectMulticallStackCalls(
            address(adapter), address(uniswapMock), USER, expectedCallData, tokenIn, tokenOut, true
        );

        // MULTICALL
        executeOneLineMulticall(creditAccount, address(adapter), callData);

        expectBalance(Tokens.DAI, creditAccount, 1);

        expectBalance(
            Tokens.WETH, creditAccount, (((initialDAIbalance - 1) / DAI_WETH_RATE) * (1_000_000 - 3000)) / 1_000_000
        );

        expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 1);

        expectTokenIsEnabled(creditAccount, Tokens.DAI, false);
        expectTokenIsEnabled(creditAccount, Tokens.WETH, true);
    }

    /// @dev [AUV3-6]: exactOutputSingle works for user as expected
    function test_AUV3_06_exactOutputSingle_works_for_user_as_expected() public {
        setUp();

        ISwapRouter.ExactOutputSingleParams memory exactOutputSingleParams = _getExactOutputSingleParams();

        (address creditAccount, uint256 initialDAIbalance) = _openTestCreditAccount();

        expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 0);

        bytes memory callData = abi.encodeCall(adapter.exactOutputSingle, (exactOutputSingleParams));

        exactOutputSingleParams.recipient = creditAccount;

        bytes memory expectedCallData = abi.encodeCall(ISwapRouter.exactOutputSingle, (exactOutputSingleParams));

        expectMulticallStackCalls(
            address(adapter),
            address(uniswapMock),
            USER,
            expectedCallData,
            exactOutputSingleParams.tokenIn,
            exactOutputSingleParams.tokenOut,
            true
        );

        // MULTICALL
        executeOneLineMulticall(creditAccount, address(adapter), callData);

        expectBalance(Tokens.DAI, creditAccount, initialDAIbalance - ((DAI_EXCHANGE_AMOUNT / 2) * 1000) / 997);

        expectBalance(Tokens.WETH, creditAccount, DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE / 2);

        expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 1);

        expectTokenIsEnabled(creditAccount, Tokens.WETH, true);
    }

    /// @dev [AUV3-7]: exactOutput works for user as expected
    function test_AUV3_07_exactOutput_works_for_user_as_expected() public {
        setUp();

        ISwapRouter.ExactOutputParams memory exactOutputParams = _getExactOutputParams();

        (address creditAccount, uint256 initialDAIbalance) = _openTestCreditAccount();

        expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 0);

        bytes memory callData = abi.encodeCall(adapter.exactOutput, (exactOutputParams));

        exactOutputParams.recipient = creditAccount;

        bytes memory expectedCallData = abi.encodeCall(ISwapRouter.exactOutput, (exactOutputParams));

        address tokenIn = tokenTestSuite.addressOf(Tokens.DAI);
        address tokenOut = tokenTestSuite.addressOf(Tokens.WETH);

        expectMulticallStackCalls(
            address(adapter), address(uniswapMock), USER, expectedCallData, tokenIn, tokenOut, true
        );

        // MULTICALL
        executeOneLineMulticall(creditAccount, address(adapter), callData);

        expectBalance(Tokens.DAI, creditAccount, initialDAIbalance - ((DAI_EXCHANGE_AMOUNT / 2) * 1000) / 997);

        expectBalance(Tokens.WETH, creditAccount, DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE / 2);

        expectAllowance(Tokens.DAI, creditAccount, address(uniswapMock), 1);

        expectTokenIsEnabled(creditAccount, Tokens.WETH, true);
    }

    /// @dev [AUV3-8]: UniswapV3 adapter can't be exploited with an incorrectly-formed path
    function test_AUV3_08_exactOutput_cannot_be_exploited_with_tailored_path_parameter() public {
        (address creditAccount,) = _openTestCreditAccount();

        ISwapRouter.ExactOutputParams memory exactOutputParams = _getExactOutputParams();
        exactOutputParams.path = exactOutputParams.path.concat(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDC)));

        vm.expectRevert(InvalidPathException.selector);
        executeOneLineMulticall(
            creditAccount, address(adapter), abi.encodeCall(adapter.exactOutput, (exactOutputParams))
        );
    }

    /// @dev [AUV3-9]: Path validity checks are correct
    function test_AUV3_09_path_validity_checks_are_correct() public {
        (address creditAccount,) = _openTestCreditAccount();

        ISwapRouter.ExactInputParams memory exactInputParams = _getExactInputParams();

        exactInputParams.path = bytes(abi.encodePacked(creditManager.underlying())).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDC)))).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDT)))).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDC)))).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.WETH))));

        vm.expectRevert(InvalidPathException.selector);
        executeOneLineMulticall(creditAccount, address(adapter), abi.encodeCall(adapter.exactInput, (exactInputParams)));

        IUniswapV3Adapter.ExactAllInputParams memory exactAllInputParams = _getAllInputParams();

        exactAllInputParams.path = bytes(abi.encodePacked(creditManager.underlying())).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDC)))).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDT)))).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDC)))).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.WETH))));

        vm.expectRevert(InvalidPathException.selector);
        executeOneLineMulticall(
            creditAccount, address(adapter), abi.encodeCall(adapter.exactAllInput, (exactAllInputParams))
        );

        ISwapRouter.ExactOutputParams memory exactOutputParams = _getExactOutputParams();

        exactOutputParams.path = bytes(abi.encodePacked(creditManager.underlying())).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDC)))).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDT)))).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDC)))).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.WETH))));

        vm.expectRevert(InvalidPathException.selector);
        executeOneLineMulticall(
            creditAccount, address(adapter), abi.encodeCall(adapter.exactOutput, (exactOutputParams))
        );

        exactInputParams.path = bytes(abi.encodePacked(creditManager.underlying())).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.LINK)))).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.WETH))));

        vm.expectRevert(InvalidPathException.selector);
        executeOneLineMulticall(creditAccount, address(adapter), abi.encodeCall(adapter.exactInput, (exactInputParams)));

        exactInputParams.path = bytes(abi.encodePacked(creditManager.underlying())).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDC)))).concat(
            bytes(abi.encodePacked(uint24(3000)))
        ).concat(bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.WETH))));

        exactInputParams.amountOutMinimum = 0;

        executeOneLineMulticall(creditAccount, address(adapter), abi.encodeCall(adapter.exactInput, (exactInputParams)));
    }
}
