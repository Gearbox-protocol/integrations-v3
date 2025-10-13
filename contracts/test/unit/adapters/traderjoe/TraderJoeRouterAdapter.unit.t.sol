// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {ITraderJoeRouter, Path, Version, IERC20} from "../../../../integrations/traderjoe/ITraderJoeRouter.sol";
import {
    ITraderJoeRouterAdapter,
    TraderJoePoolStatus,
    TraderJoePool
} from "../../../../interfaces/traderjoe/ITraderJoeRouterAdapter.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {TraderJoeRouterAdapterHarness} from "./TraderJoeRouterAdapter.harness.sol";

import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

/// @title TraderJoe adapter unit test
/// @notice U:[TJ-1]: Unit tests for TraderJoe swap router adapter
contract TraderJoeRouterAdapterUnitTest is AdapterUnitTestHelper {
    TraderJoeRouterAdapterHarness adapter;
    address router;

    function setUp() public {
        _setUp();

        router = makeAddr("ROUTER");
        adapter = new TraderJoeRouterAdapterHarness(address(creditManager), router);

        _setPoolsStatus(3, 7);
    }

    /// @notice U:[TJ-1]: Constructor works as expected
    function test_U_TJ_01_constructor_works_as_expected() public view {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), router, "Incorrect targetContract");
    }

    /// @notice U:[TJ-2]: Wrapper functions revert on wrong caller
    function test_U_TJ_02_wrapper_functions_revert_on_wrong_caller() public {
        Path memory emptyPath;

        _revertsOnNonFacadeCaller();
        adapter.swapExactTokensForTokens(0, 0, emptyPath, address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.swapExactTokensForTokensSupportingFeeOnTransferTokens(0, 0, emptyPath, address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.swapDiffTokensForTokens(0, 0, emptyPath, 0);

        _revertsOnNonFacadeCaller();
        adapter.swapDiffTokensForTokensSupportingFeeOnTransferTokens(0, 0, emptyPath, 0);
    }

    /// @notice U:[TJ-3]: `swapExactTokensForTokens` works as expected
    function test_U_TJ_03_swapExactTokensForTokens_works_as_expected() public {
        Path memory path = _makePath(0);
        vm.expectRevert(ITraderJoeRouterAdapter.InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.swapExactTokensForTokens(123, 456, path, address(0), 789);

        path = _makePath(2);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            callData: abi.encodeCall(ITraderJoeRouter.swapExactTokensForTokens, (123, 456, path, creditAccount, 789)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.swapExactTokensForTokens(123, 456, path, address(0), 789);
        assertTrue(useSafePrices);
    }

    /// @notice U:[TJ-4]: `swapExactTokensForTokensSupportingFeeOnTransferTokens` works as expected
    function test_U_TJ_04_swapExactTokensForTokensSupportingFeeOnTransferTokens_works_as_expected() public {
        Path memory path = _makePath(0);
        vm.expectRevert(ITraderJoeRouterAdapter.InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.swapExactTokensForTokensSupportingFeeOnTransferTokens(123, 456, path, address(0), 789);

        path = _makePath(2);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            callData: abi.encodeCall(
                ITraderJoeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens, (123, 456, path, creditAccount, 789)
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices =
            adapter.swapExactTokensForTokensSupportingFeeOnTransferTokens(123, 456, path, address(0), 789);
        assertTrue(useSafePrices);
    }

    /// @notice U:[TJ-5]: `swapDiffTokensForTokens` works as expected
    function test_U_TJ_05_swapDiffTokensForTokens_works_as_expected() public diffTestCases {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        Path memory path = _makePath(0);
        vm.expectRevert(ITraderJoeRouterAdapter.InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.swapDiffTokensForTokens(diffInputAmount, 0.5e27, path, 789);

        path = _makePath(2);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            callData: abi.encodeCall(
                ITraderJoeRouter.swapExactTokensForTokens, (diffInputAmount, diffInputAmount / 2, path, creditAccount, 789)
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.swapDiffTokensForTokens(diffLeftoverAmount, 0.5e27, path, 789);
        assertTrue(useSafePrices);
    }

    /// @notice U:[TJ-6]: `swapDiffTokensForTokensSupportingFeeOnTransferTokens` works as expected
    function test_U_TJ_06_swapDiffTokensForTokensSupportingFeeOnTransferTokens_works_as_expected()
        public
        diffTestCases
    {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        Path memory path = _makePath(0);
        vm.expectRevert(ITraderJoeRouterAdapter.InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.swapDiffTokensForTokensSupportingFeeOnTransferTokens(diffInputAmount, 0.5e27, path, 789);

        path = _makePath(2);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            callData: abi.encodeCall(
                ITraderJoeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens,
                (diffInputAmount, diffInputAmount / 2, path, creditAccount, 789)
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices =
            adapter.swapDiffTokensForTokensSupportingFeeOnTransferTokens(diffLeftoverAmount, 0.5e27, path, 789);
        assertTrue(useSafePrices);
    }

    /// @notice U:[TJ-7]: `setPoolStatusBatch` works as expected
    function test_U_TJ_07_setPoolStatusBatch_works_as_expected() public {
        _setPoolsStatus(3, 0);
        TraderJoePoolStatus[] memory pools = new TraderJoePoolStatus[](1);

        _revertsOnNonConfiguratorCaller();
        adapter.setPoolStatusBatch(pools);

        pools[0] = TraderJoePoolStatus(tokens[0], DUMB_ADDRESS, 10, Version.V2, true);
        _revertsOnUnknownToken();
        vm.prank(configurator);
        adapter.setPoolStatusBatch(pools);

        pools = new TraderJoePoolStatus[](2);
        pools[0] = TraderJoePoolStatus(tokens[0], tokens[1], 10, Version.V2, false);
        pools[1] = TraderJoePoolStatus(tokens[1], tokens[2], 20, Version.V2_1, true);

        _readsTokenMask(tokens[1]);
        _readsTokenMask(tokens[2]);

        vm.expectEmit(true, true, false, true);
        emit ITraderJoeRouterAdapter.SetPoolStatus(
            _min(tokens[0], tokens[1]), _max(tokens[0], tokens[1]), 10, Version.V2, false
        );

        vm.expectEmit(true, true, false, true);
        emit ITraderJoeRouterAdapter.SetPoolStatus(
            _min(tokens[1], tokens[2]), _max(tokens[1], tokens[2]), 20, Version.V2_1, true
        );

        vm.prank(configurator);
        adapter.setPoolStatusBatch(pools);

        assertFalse(adapter.isPoolAllowed(tokens[0], tokens[1], 10, Version.V2), "First pair incorrectly allowed");
        assertTrue(adapter.isPoolAllowed(tokens[1], tokens[2], 20, Version.V2_1), "Second pair incorrectly not allowed");

        TraderJoePool[] memory allowedPools = adapter.supportedPools();

        assertEq(allowedPools.length, 1, "Incorrect allowed pairs length");
        assertEq(allowedPools[0].token0, _min(tokens[1], tokens[2]), "Incorrect allowed pool token 0");
        assertEq(allowedPools[0].token1, _max(tokens[1], tokens[2]), "Incorrect allowed pool token 1");
        assertEq(allowedPools[0].binStep, 20, "Incorrect allowed pool binStep");
        assertEq(uint8(allowedPools[0].poolVersion), uint8(Version.V2_1), "Incorrect allowed pool version");
    }

    /// @notice U:[TJ-8]: `_validatePath` works as expected
    function test_U_TJ_08_validatePath_works_as_expected() public {
        bool isValid;
        address tokenIn;
        Path memory path;

        // insane paths
        (isValid,) = adapter.validatePath(_makePath(0));
        assertFalse(isValid, "Empty path incorrectly valid");

        (isValid,) = adapter.validatePath(_makePath(5));
        assertFalse(isValid, "Long path incorrectly valid");

        // path with mismatched array lengths
        path = _makePath(3);
        path.pairBinSteps = new uint256[](1);
        (isValid,) = adapter.validatePath(path);
        assertFalse(isValid, "Path with mismatched arrays incorrectly valid");

        // Path with correct length but invalid pools
        path = _makePath(3);
        _setPoolsStatus(3, 0); // Set all pools as invalid
        (isValid, tokenIn) = adapter.validatePath(path);
        assertFalse(isValid, "Path with invalid pools incorrectly valid");

        // Valid path
        path = _makePath(3);
        _setPoolsStatus(3, 7); // Set all pools as valid
        (isValid, tokenIn) = adapter.validatePath(path);
        assertTrue(isValid, "Valid path incorrectly invalid");
        assertEq(tokenIn, tokens[0], "Incorrect tokenIn for valid path");

        // Path with break in the middle
        path = _makePath(3);
        _setPoolsStatus(3, 5); // Set pool 1-2 as invalid
        (isValid, tokenIn) = adapter.validatePath(path);
        assertFalse(isValid, "Path with middle break incorrectly valid");
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Returns a swap path with specified length (number of tokens = length + 1)
    function _makePath(uint256 len) internal view returns (Path memory path) {
        if (len < 2) {
            return path; // Return empty path for len < 2
        }

        path.tokenPath = new IERC20[](len);
        path.pairBinSteps = new uint256[](len - 1);
        path.versions = new Version[](len - 1);

        for (uint256 i = 0; i < len; i++) {
            path.tokenPath[i] = IERC20(tokens[i]);
        }

        for (uint256 i = 0; i < len - 1; i++) {
            path.pairBinSteps[i] = 10 * (i + 1); // 10, 20, 30, ...
            path.versions[i] = Version.V2;
        }

        return path;
    }

    /// @dev Sets statuses for `len` consecutive pairs of `tokens` based on `allowedPoolsMask`
    function _setPoolsStatus(uint256 len, uint256 allowedPoolsMask) internal {
        TraderJoePoolStatus[] memory pools = new TraderJoePoolStatus[](len);
        for (uint256 i = 0; i < len; i++) {
            uint256 mask = 1 << i;
            pools[i] =
                TraderJoePoolStatus(tokens[i], tokens[i + 1], 10 * (i + 1), Version.V2, allowedPoolsMask & mask != 0);
        }
        vm.prank(configurator);
        adapter.setPoolStatusBatch(pools);
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
