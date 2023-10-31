// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ISwapRouter} from "../../../../integrations/uniswap/IUniswapV3.sol";
import {
    IUniswapV3AdapterEvents,
    IUniswapV3AdapterExceptions,
    IUniswapV3AdapterTypes,
    UniswapV3PoolStatus
} from "../../../../interfaces/uniswap/IUniswapV3Adapter.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {UniswapV3AdapterHarness} from "./UniswapV3Adapter.harness.sol";

/// @title Uniswap v3 adapter unit test
/// @notice U:[UNI3]: Unit tests for Uniswap v3 swap router adapter
contract UniswapV3AdapterUnitTest is
    AdapterUnitTestHelper,
    IUniswapV3AdapterEvents,
    IUniswapV3AdapterExceptions,
    IUniswapV3AdapterTypes
{
    UniswapV3AdapterHarness adapter;

    address router;

    function setUp() public {
        _setUp();

        router = makeAddr("ROUTER");
        adapter = new UniswapV3AdapterHarness(address(creditManager), router);

        _setPoolsStatus(3, 7);
    }

    /// @notice U:[UNI3-1]: Constructor works as expected
    function test_U_UNI3_01_constructor_works_as_expected() public {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.addressProvider(), address(addressProvider), "Incorrect addressProvider");
        assertEq(adapter.targetContract(), router, "Incorrect targetContract");
    }

    /// @notice U:[UNI3-2]: Wrapper functions revert on wrong caller
    function test_U_UNI3_02_wrapper_functions_revert_on_wrong_caller() public {
        ISwapRouter.ExactInputSingleParams memory p1;
        _revertsOnNonFacadeCaller();
        adapter.exactInputSingle(p1);

        ExactDiffInputSingleParams memory p2_2;
        _revertsOnNonFacadeCaller();
        adapter.exactDiffInputSingle(p2_2);

        ExactAllInputSingleParams memory p2;
        _revertsOnNonFacadeCaller();
        adapter.exactAllInputSingle(p2);

        ISwapRouter.ExactInputParams memory p3;
        _revertsOnNonFacadeCaller();
        adapter.exactInput(p3);

        ExactDiffInputParams memory p4_2;
        _revertsOnNonFacadeCaller();
        adapter.exactDiffInput(p4_2);

        ExactAllInputParams memory p4;
        _revertsOnNonFacadeCaller();
        adapter.exactAllInput(p4);

        ISwapRouter.ExactOutputSingleParams memory p5;
        _revertsOnNonFacadeCaller();
        adapter.exactOutputSingle(p5);

        ISwapRouter.ExactOutputParams memory p6;
        _revertsOnNonFacadeCaller();
        adapter.exactOutput(p6);
    }

    /// @notice U:[UNI3-3]: `exactInputSingle` works as expected
    function test_U_UNI3_03_exactInputSingle_works_as_expected() public {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            fee: 500,
            amountIn: 123,
            amountOutMinimum: 456,
            deadline: 789,
            recipient: creditAccount,
            sqrtPriceLimitX96: 0
        });

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(ISwapRouter.exactInputSingle, (params)),
            requiresApproval: true,
            validatesTokens: true
        });

        params.recipient = address(0);
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactInputSingle(params);

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[UNI3-4]: `exactAllInputSingle` works as expected
    function test_U_UNI3_04_exactAllInputSingle_works_as_expected() public {
        deal({token: tokens[0], to: creditAccount, give: 1001});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(
                ISwapRouter.exactInputSingle,
                (
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: tokens[0],
                        tokenOut: tokens[1],
                        fee: 500,
                        amountIn: 1000,
                        amountOutMinimum: 500,
                        deadline: 789,
                        recipient: creditAccount,
                        sqrtPriceLimitX96: 0
                    })
                )
                ),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactAllInputSingle(
            ExactAllInputSingleParams({
                tokenIn: tokens[0],
                tokenOut: tokens[1],
                fee: 500,
                deadline: 789,
                rateMinRAY: 0.5e27,
                sqrtPriceLimitX96: 0
            })
        );

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 1, "Incorrect tokensToDisable");
    }

    /// @notice U:[UNI3-4A]: `exactDiffInputSingle` works as expected
    function test_U_UNI3_04A_exactDiffInputSingle_works_as_expected() public diffTestCases {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(
                ISwapRouter.exactInputSingle,
                (
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: tokens[0],
                        tokenOut: tokens[1],
                        fee: 500,
                        amountIn: diffInputAmount,
                        amountOutMinimum: diffInputAmount / 2,
                        deadline: 789,
                        recipient: creditAccount,
                        sqrtPriceLimitX96: 0
                    })
                )
                ),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactDiffInputSingle(
            ExactDiffInputSingleParams({
                tokenIn: tokens[0],
                tokenOut: tokens[1],
                fee: 500,
                deadline: 789,
                leftoverAmount: diffLeftoverAmount,
                rateMinRAY: 0.5e27,
                sqrtPriceLimitX96: 0
            })
        );

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? 1 : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[UNI3-5]: `exactInput` works as expected
    function test_U_UNI3_05_exactInput_works_as_expected() public {
        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: _makePath(0),
            amountIn: 123,
            amountOutMinimum: 456,
            deadline: 789,
            recipient: creditAccount
        });
        vm.expectRevert(InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.exactInput(params);

        params.path = _makePath(3);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[2],
            callData: abi.encodeCall(ISwapRouter.exactInput, (params)),
            requiresApproval: true,
            validatesTokens: true
        });

        params.recipient = address(0);
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactInput(params);

        assertEq(tokensToEnable, 4, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[UNI3-6]: `exactAllInput` works as expected
    function test_U_UNI3_06_exactAllInput_works_as_expected() public {
        deal({token: tokens[0], to: creditAccount, give: 1001});

        ExactAllInputParams memory params = ExactAllInputParams({path: _makePath(0), deadline: 789, rateMinRAY: 0.5e27});
        vm.expectRevert(InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.exactAllInput(params);

        params.path = _makePath(3);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[2],
            callData: abi.encodeCall(
                ISwapRouter.exactInput,
                (
                    ISwapRouter.ExactInputParams({
                        path: params.path,
                        amountIn: 1000,
                        amountOutMinimum: 500,
                        deadline: 789,
                        recipient: creditAccount
                    })
                )
                ),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactAllInput(params);

        assertEq(tokensToEnable, 4, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 1, "Incorrect tokensToDisable");
    }

    /// @notice U:[UNI3-6A]: `exactDiffInput` works as expected
    function test_U_UNI3_06A_exactDiffInput_works_as_expected() public diffTestCases {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        ExactDiffInputParams memory params = ExactDiffInputParams({
            path: _makePath(0),
            deadline: 789,
            leftoverAmount: diffLeftoverAmount,
            rateMinRAY: 0.5e27
        });
        vm.expectRevert(InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.exactDiffInput(params);

        params.path = _makePath(3);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[2],
            callData: abi.encodeCall(
                ISwapRouter.exactInput,
                (
                    ISwapRouter.ExactInputParams({
                        path: params.path,
                        amountIn: diffInputAmount,
                        amountOutMinimum: diffInputAmount / 2,
                        deadline: 789,
                        recipient: creditAccount
                    })
                )
                ),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactDiffInput(params);

        assertEq(tokensToEnable, 4, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? 1 : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[UNI3-7]: `exactOutputSingle` works as expected
    function test_U_UNI3_07_exactOutputSingle_works_as_expected() public {
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            fee: 500,
            amountOut: 123,
            amountInMaximum: 456,
            deadline: 789,
            recipient: creditAccount,
            sqrtPriceLimitX96: 0
        });

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(ISwapRouter.exactOutputSingle, (params)),
            requiresApproval: true,
            validatesTokens: true
        });

        params.recipient = address(0);
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactOutputSingle(params);

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[UNI3-8]: `exactOutput` works as expected
    function test_U_UNI3_08_exactOutput_works_as_expected() public {
        ISwapRouter.ExactOutputParams memory params = ISwapRouter.ExactOutputParams({
            path: _makePath(0),
            amountOut: 123,
            amountInMaximum: 456,
            deadline: 789,
            recipient: creditAccount
        });
        vm.expectRevert(InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.exactOutput(params);

        params.path = _makePath(3);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[2], // path is reversed for exactOutput
            tokenOut: tokens[0],
            callData: abi.encodeCall(ISwapRouter.exactOutput, (params)),
            requiresApproval: true,
            validatesTokens: true
        });

        params.recipient = address(0);
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactOutput(params);

        assertEq(tokensToEnable, 1, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[UNI3-9]: `setPoolStatusBatch` works as expected
    function test_U_UNI3_09_setPoolStatusBatch_works_as_expected() public {
        UniswapV3PoolStatus[] memory pairs;

        _revertsOnNonConfiguratorCaller();
        adapter.setPoolStatusBatch(pairs);

        pairs = new UniswapV3PoolStatus[](2);
        pairs[0] = UniswapV3PoolStatus(tokens[0], tokens[1], 500, false);
        pairs[1] = UniswapV3PoolStatus(tokens[1], tokens[2], 3000, true);

        vm.expectEmit(true, true, true, true);
        emit SetPoolStatus(_min(tokens[0], tokens[1]), _max(tokens[0], tokens[1]), 500, false);

        vm.expectEmit(true, true, true, true);
        emit SetPoolStatus(_min(tokens[1], tokens[2]), _max(tokens[1], tokens[2]), 3000, true);

        vm.prank(configurator);
        adapter.setPoolStatusBatch(pairs);

        assertFalse(adapter.isPoolAllowed(tokens[0], tokens[1], 500), "First pool incorrectly allowed");
        assertTrue(adapter.isPoolAllowed(tokens[1], tokens[2], 3000), "Second pool incorrectly not allowed");
    }

    /// @notice U:[UNI3-10]: `_validatePath` works as expected
    function test_U_UNI3_10_validatePath_works_as_expected() public {
        bool isValid;
        address tokenIn;
        address tokenOut;
        bytes memory path;

        // insane path
        (isValid,,) = adapter.validatePath(bytes(""));
        assertFalse(isValid, "Empty path incorrectly valid");

        (isValid,,) = adapter.validatePath(bytes("some random string that does not represent a valid path"));
        assertFalse(isValid, "Arbitrary path incorrectly valid");

        // valid paths over recognized tokens but through pools with wrong fees
        path = abi.encodePacked(tokens[0], uint24(3000), tokens[1]);
        (isValid,,) = adapter.validatePath(path);
        assertFalse(isValid, "2-hop path through pool with wrong fee is incorrectly valid");

        path = abi.encodePacked(tokens[0], uint24(500), tokens[1], uint24(3000), tokens[2]);
        (isValid,,) = adapter.validatePath(path);
        assertFalse(isValid, "3-hop path through pool with wrong fee is incorrectly valid");

        path = abi.encodePacked(tokens[0], uint24(500), tokens[1], uint24(500), tokens[2], uint24(3000), tokens[3]);
        (isValid,,) = adapter.validatePath(path);
        assertFalse(isValid, "4-hop path through pool with wrong fee is incorrectly valid");

        // exhaustive search
        for (uint256 pathLen = 2; pathLen <= 4; ++pathLen) {
            path = _makePath(pathLen);

            uint256 numCases = 1 << (pathLen - 1);
            for (uint256 mask; mask < numCases; ++mask) {
                _setPoolsStatus(pathLen - 1, mask);
                (isValid, tokenIn, tokenOut) = adapter.validatePath(path);

                if (mask == numCases - 1) {
                    assertTrue(isValid, "Path incorrectly invalid");
                    assertEq(tokenIn, tokens[0], "Incorrect tokenIn");
                    assertEq(tokenOut, tokens[pathLen - 1], "Incorrect tokenOut");
                } else {
                    assertFalse(isValid, "Path incorrectly valid");
                }
            }
        }
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Returns swap path of `len` consecutive `tokens`
    function _makePath(uint256 len) internal view returns (bytes memory path) {
        uint24 fee = 500;
        if (len == 2) path = abi.encodePacked(tokens[0], fee, tokens[1]);
        if (len == 3) path = abi.encodePacked(tokens[0], fee, tokens[1], fee, tokens[2]);
        if (len == 4) path = abi.encodePacked(tokens[0], fee, tokens[1], fee, tokens[2], fee, tokens[3]);
    }

    /// @dev Sets statuses for `len` consecutive pools of `tokens` based on `allowedPoolsMask`
    function _setPoolsStatus(uint256 len, uint256 allowedPairsMask) internal {
        UniswapV3PoolStatus[] memory pairs = new UniswapV3PoolStatus[](len);
        for (uint256 i; i < len; ++i) {
            uint256 mask = 1 << i;
            pairs[i] = UniswapV3PoolStatus(tokens[i], tokens[i + 1], 500, allowedPairsMask & mask != 0);
        }
        vm.prank(configurator);
        adapter.setPoolStatusBatch(pairs);
    }

    /// @dev Returns smaller of two addresses
    function _min(address token0, address token1) internal pure returns (address) {
        return token0 < token1 ? token0 : token1;
    }

    /// @dev Returns larger of two addresses
    function _max(address token0, address token1) internal pure returns (address) {
        return token0 < token1 ? token1 : token0;
    }
}
