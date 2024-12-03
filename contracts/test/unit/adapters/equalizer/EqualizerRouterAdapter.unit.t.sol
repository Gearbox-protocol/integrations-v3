// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IEqualizerRouter, Route} from "../../../../integrations/equalizer/IEqualizerRouter.sol";
import {
    IEqualizerRouterAdapter,
    EqualizerPoolStatus,
    EqualizerPool
} from "../../../../interfaces/equalizer/IEqualizerRouterAdapter.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {EqualizerRouterAdapterHarness} from "./EqualizerRouterAdapter.harness.sol";

import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

/// @title Equalizer adapter unit test
/// @notice U:[EQLZ-1]: Unit tests for Equalizer swap router adapter
contract EqualizerRouterAdapterUnitTest is AdapterUnitTestHelper {
    EqualizerRouterAdapterHarness adapter;
    address router;

    function setUp() public {
        _setUp();

        router = makeAddr("ROUTER");
        adapter = new EqualizerRouterAdapterHarness(address(creditManager), router);

        _setPoolsStatus(3, 7);
    }

    /// @notice U:[EQLZ-1]: Constructor works as expected
    function test_U_EQLZ_01_constructor_works_as_expected() public view {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), router, "Incorrect targetContract");
    }

    /// @notice U:[EQLZ-2]: Wrapper functions revert on wrong caller
    function test_U_EQLZ_02_wrapper_functions_revert_on_wrong_caller() public {
        Route[] memory emptyPath;

        _revertsOnNonFacadeCaller();
        adapter.swapExactTokensForTokens(0, 0, emptyPath, address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.swapDiffTokensForTokens(0, 0, emptyPath, 0);
    }

    /// @notice U:[EQLZ-3]: `swapExactTokensForTokens` works as expected
    function test_U_EQLZ_03_swapExactTokensForTokens_works_as_expected() public {
        Route[] memory routes = _makePath(0);
        vm.expectRevert(IEqualizerRouterAdapter.InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.swapExactTokensForTokens(123, 456, routes, address(0), 789);

        routes = _makePath(2);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            callData: abi.encodeCall(IEqualizerRouter.swapExactTokensForTokens, (123, 456, routes, creditAccount, 789)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.swapExactTokensForTokens(123, 456, routes, address(0), 789);
        assertTrue(useSafePrices);
    }

    /// @notice U:[EQLZ-4]: `swapDiffTokensForTokens` works as expected
    function test_U_EQLZ_04_swapDiffTokensForTokens_works_as_expected() public diffTestCases {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        Route[] memory routes = _makePath(0);
        vm.expectRevert(IEqualizerRouterAdapter.InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.swapDiffTokensForTokens(diffInputAmount, 0.5e27, routes, 789);

        routes = _makePath(2);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            callData: abi.encodeCall(
                IEqualizerRouter.swapExactTokensForTokens,
                (diffInputAmount, diffInputAmount / 2, routes, creditAccount, 789)
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.swapDiffTokensForTokens(diffLeftoverAmount, 0.5e27, routes, 789);
        assertTrue(useSafePrices);
    }

    /// @notice U:[EQLZ-5]: `setPoolStatusBatch` works as expected
    function test_U_EQLZ_05_setPoolStatusBatch_works_as_expected() public {
        _setPoolsStatus(3, 0);
        EqualizerPoolStatus[] memory pools = new EqualizerPoolStatus[](1);

        _revertsOnNonConfiguratorCaller();
        adapter.setPoolStatusBatch(pools);

        pools[0] = EqualizerPoolStatus(tokens[0], DUMB_ADDRESS, false, true);
        _revertsOnUnknownToken();
        vm.prank(configurator);
        adapter.setPoolStatusBatch(pools);

        pools = new EqualizerPoolStatus[](2);
        pools[0] = EqualizerPoolStatus(tokens[0], tokens[1], false, false);
        pools[1] = EqualizerPoolStatus(tokens[1], tokens[2], true, true);

        _readsTokenMask(tokens[1]);
        _readsTokenMask(tokens[2]);

        vm.expectEmit(true, true, false, true);
        emit IEqualizerRouterAdapter.SetPoolStatus(_min(tokens[0], tokens[1]), _max(tokens[0], tokens[1]), false, false);

        vm.expectEmit(true, true, false, true);
        emit IEqualizerRouterAdapter.SetPoolStatus(_min(tokens[1], tokens[2]), _max(tokens[1], tokens[2]), true, true);

        vm.prank(configurator);
        adapter.setPoolStatusBatch(pools);

        assertFalse(adapter.isPoolAllowed(tokens[0], tokens[1], false), "First pair incorrectly allowed");
        assertTrue(adapter.isPoolAllowed(tokens[1], tokens[2], true), "Second pair incorrectly not allowed");

        EqualizerPool[] memory allowedPools = adapter.supportedPools();

        assertEq(allowedPools.length, 1, "Incorrect allowed pairs length");
        assertEq(allowedPools[0].token0, _min(tokens[1], tokens[2]), "Incorrect allowed pool token 0");
        assertEq(allowedPools[0].token1, _max(tokens[1], tokens[2]), "Incorrect allowed pool token 1");
        assertTrue(allowedPools[0].stable, "Incorrect allowed pools stable status");
    }

    /// @notice U:[EQLZ-6]: `_validatePath` works as expected
    function test_U_EQLZ_06_validatePath_works_as_expected() public {
        bool isValid;
        address tokenIn;
        Route[] memory routes;

        // insane paths
        (isValid,) = adapter.validatePath(new Route[](0));
        assertFalse(isValid, "Empty path incorrectly valid");

        (isValid,) = adapter.validatePath(new Route[](4));
        assertFalse(isValid, "Long path incorrectly valid");

        // exhaustive search
        for (uint256 pathLen = 2; pathLen <= 4; ++pathLen) {
            routes = _makePath(pathLen);

            uint256 numCases = 1 << (pathLen - 1);
            for (uint256 mask; mask < numCases; ++mask) {
                _setPoolsStatus(pathLen - 1, mask);
                (isValid, tokenIn) = adapter.validatePath(routes);

                if (mask == numCases - 1) {
                    assertTrue(isValid, "Path incorrectly invalid");
                    assertEq(tokenIn, tokens[0], "Incorrect tokenIn");
                } else {
                    assertFalse(isValid, "Path incorrectly valid");
                }
            }
        }
    }

    /// @notice U:[EQLZ-7]: `_validatePath` works as expected
    function test_U_EQLZ_07_validatePath_filters_disjunct_paths() public {
        bool isValid;
        address tokenIn;
        Route[] memory routes;

        EqualizerPoolStatus[] memory pools = new EqualizerPoolStatus[](2);
        pools[0] = EqualizerPoolStatus(tokens[0], tokens[1], false, true);
        pools[1] = EqualizerPoolStatus(tokens[2], tokens[3], false, true);
        vm.prank(configurator);
        adapter.setPoolStatusBatch(pools);

        routes = new Route[](2);
        routes[0] = Route({from: tokens[0], to: tokens[1], stable: false});
        routes[1] = Route({from: tokens[2], to: tokens[3], stable: false});

        (isValid, tokenIn) = adapter.validatePath(routes);

        assertFalse(isValid, "Path incorrectly valid");
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Returns swap path of `len` consecutive `tokens`
    function _makePath(uint256 len) internal view returns (Route[] memory routes) {
        if (len == 0 || len == 1) return new Route[](0);

        routes = new Route[](len - 1);
        for (uint256 i; i < len - 1; ++i) {
            routes[i] = Route({from: tokens[i], to: tokens[i + 1], stable: false});
        }
    }

    /// @dev Sets statuses for `len` consecutive pairs of `tokens` based on `allowedPoolsMask`
    function _setPoolsStatus(uint256 len, uint256 allowedPoolsMask) internal {
        EqualizerPoolStatus[] memory pools = new EqualizerPoolStatus[](len);
        for (uint256 i; i < len; ++i) {
            uint256 mask = 1 << i;
            pools[i] = EqualizerPoolStatus(tokens[i], tokens[i + 1], false, allowedPoolsMask & mask != 0);
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
