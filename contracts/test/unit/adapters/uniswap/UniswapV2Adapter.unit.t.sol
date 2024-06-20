// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IUniswapV2Router01} from "../../../../integrations/uniswap/IUniswapV2Router01.sol";
import {
    IUniswapV2AdapterEvents,
    IUniswapV2AdapterExceptions,
    UniswapV2PairStatus,
    UniswapV2Pair
} from "../../../../interfaces/uniswap/IUniswapV2Adapter.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {UniswapV2AdapterHarness} from "./UniswapV2Adapter.harness.sol";

/// @title Uniswap v2 adapter unit test
/// @notice U:[UNI2]: Unit tests for Uniswap v2 swap router adapter
contract UniswapV2AdapterUnitTest is AdapterUnitTestHelper, IUniswapV2AdapterEvents, IUniswapV2AdapterExceptions {
    UniswapV2AdapterHarness adapter;

    address router;

    function setUp() public {
        _setUp();

        router = makeAddr("ROUTER");
        adapter = new UniswapV2AdapterHarness(address(creditManager), router);

        _setPairsStatus(3, 7);
    }

    /// @notice U:[UNI2-1]: Constructor works as expected
    function test_U_UNI2_01_constructor_works_as_expected() public {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), router, "Incorrect targetContract");
    }

    /// @notice U:[UNI2-2]: Wrapper functions revert on wrong caller
    function test_U_UNI2_02_wrapper_functions_revert_on_wrong_caller() public {
        address[] memory emptyPath;

        _revertsOnNonFacadeCaller();
        adapter.swapTokensForExactTokens(0, 0, emptyPath, address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.swapExactTokensForTokens(0, 0, emptyPath, address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.swapDiffTokensForTokens(0, 0, emptyPath, 0);
    }

    /// @notice U:[UNI2-3]: `swapTokensForExactTokens` works as expected
    function test_U_UNI2_03_swapTokensForExactTokens_works_as_expected() public {
        address[] memory path = _makePath(0);
        vm.expectRevert(InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.swapExactTokensForTokens(123, 456, path, address(0), 789);

        path = _makePath(2);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(IUniswapV2Router01.swapExactTokensForTokens, (123, 456, path, creditAccount, 789)),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.swapExactTokensForTokens(123, 456, path, address(0), 789);

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[UNI2-4]: `swapExactTokensForTokens` works as expected
    function test_U_UNI2_04_swapExactTokensForTokens_works_as_expected() public {
        address[] memory path = _makePath(0);
        vm.expectRevert(InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.swapExactTokensForTokens(123, 456, path, address(0), 789);

        path = _makePath(2);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(IUniswapV2Router01.swapExactTokensForTokens, (123, 456, path, creditAccount, 789)),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.swapExactTokensForTokens(123, 456, path, address(0), 789);

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[UNI2-5]: `swapDiffTokensForTokens` works as expected
    function test_U_UNI2_05_swapDiffTokensForTokens_works_as_expected() public diffTestCases {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        address[] memory path = _makePath(0);
        vm.expectRevert(InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.swapDiffTokensForTokens(diffInputAmount, 0.5e27, path, 789);

        path = _makePath(2);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(
                IUniswapV2Router01.swapExactTokensForTokens,
                (diffInputAmount, diffInputAmount / 2, path, creditAccount, 789)
                ),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.swapDiffTokensForTokens(diffLeftoverAmount, 0.5e27, path, 789);

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? 1 : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[UNI2-6]: `setPairStatusBatch` works as expected
    function test_U_UNI2_06_setPairStatusBatch_works_as_expected() public {
        _setPairsStatus(3, 0);
        UniswapV2PairStatus[] memory pairs;

        _revertsOnNonConfiguratorCaller();
        adapter.setPairStatusBatch(pairs);

        pairs = new UniswapV2PairStatus[](2);
        pairs[0] = UniswapV2PairStatus(tokens[0], tokens[1], false);
        pairs[1] = UniswapV2PairStatus(tokens[1], tokens[2], true);

        vm.expectEmit(true, true, false, true);
        emit SetPairStatus(_min(tokens[0], tokens[1]), _max(tokens[0], tokens[1]), false);

        vm.expectEmit(true, true, false, true);
        emit SetPairStatus(_min(tokens[1], tokens[2]), _max(tokens[1], tokens[2]), true);

        vm.prank(configurator);
        adapter.setPairStatusBatch(pairs);

        assertFalse(adapter.isPairAllowed(tokens[0], tokens[1]), "First pair incorrectly allowed");
        assertTrue(adapter.isPairAllowed(tokens[1], tokens[2]), "Second pair incorrectly not allowed");

        UniswapV2Pair[] memory allowedPairs = adapter.supportedPairs();

        assertEq(allowedPairs.length, 1, "Incorrect allowed pairs length");

        assertEq(allowedPairs[0].token0, _min(tokens[1], tokens[2]), "Incorrect allowed pair token 0");

        assertEq(allowedPairs[0].token1, _max(tokens[1], tokens[2]), "Incorrect allowed pair token 1");
    }

    /// @notice U:[UNI2-7]: `_validatePath` works as expected
    function test_U_UNI2_07_validatePath_works_as_expected() public {
        bool isValid;
        address tokenIn;
        address tokenOut;
        address[] memory path;

        // insane paths
        (isValid,,) = adapter.validatePath(new address[](0));
        assertFalse(isValid, "Empty path incorrectly valid");

        (isValid,,) = adapter.validatePath(new address[](1));
        assertFalse(isValid, "Short path incorrectly valid");

        (isValid,,) = adapter.validatePath(new address[](5));
        assertFalse(isValid, "Long path incorrectly valid");

        // exhaustive search
        for (uint256 pathLen = 2; pathLen <= 4; ++pathLen) {
            path = _makePath(pathLen);

            uint256 numCases = 1 << (pathLen - 1);
            for (uint256 mask; mask < numCases; ++mask) {
                _setPairsStatus(pathLen - 1, mask);
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
    function _makePath(uint256 len) internal view returns (address[] memory path) {
        path = new address[](len);
        for (uint256 i; i < len; ++i) {
            path[i] = tokens[i];
        }
    }

    /// @dev Sets statuses for `len` consecutive pairs of `tokens` based on `allowedPairsMask`
    function _setPairsStatus(uint256 len, uint256 allowedPairsMask) internal {
        UniswapV2PairStatus[] memory pairs = new UniswapV2PairStatus[](len);
        for (uint256 i; i < len; ++i) {
            uint256 mask = 1 << i;
            pairs[i] = UniswapV2PairStatus(tokens[i], tokens[i + 1], allowedPairsMask & mask != 0);
        }
        vm.prank(configurator);
        adapter.setPairStatusBatch(pairs);
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
