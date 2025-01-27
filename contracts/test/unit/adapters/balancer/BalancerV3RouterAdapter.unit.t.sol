// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IBalancerV3Router} from "../../../../integrations/balancer/IBalancerV3Router.sol";
import {
    IBalancerV3RouterAdapter,
    IBalancerV3RouterAdapterEvents,
    IBalancerV3RouterAdapterExceptions
} from "../../../../interfaces/balancer/IBalancerV3RouterAdapter.sol";
import {BalancerV3RouterAdapter} from "../../../../adapters/balancer/BalancerV3RouterAdapter.sol";

import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Balancer V3 Router adapter unit test
/// @notice U:[BAL3]: Unit tests for Balancer V3 Router adapter
contract BalancerV3RouterAdapterUnitTest is
    AdapterUnitTestHelper,
    IBalancerV3RouterAdapterEvents,
    IBalancerV3RouterAdapterExceptions
{
    BalancerV3RouterAdapter adapter;

    address router;
    address pool;

    function setUp() public {
        _setUp();

        router = makeAddr("ROUTER");
        pool = makeAddr("POOL");
        adapter = new BalancerV3RouterAdapter(address(creditManager), router);

        // Set pool as allowed
        address[] memory pools = new address[](1);
        pools[0] = pool;
        bool[] memory statuses = new bool[](1);
        statuses[0] = true;
        vm.prank(configurator);
        adapter.setPoolStatusBatch(pools, statuses);
    }

    /// @notice U:[BAL3-1]: Constructor works as expected
    function test_U_BAL3_01_constructor_works_as_expected() public {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.addressProvider(), address(addressProvider), "Incorrect addressProvider");
        assertEq(adapter.targetContract(), router, "Incorrect targetContract");
    }

    /// @notice U:[BAL3-2]: Wrapper functions revert on wrong caller
    function test_U_BAL3_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.swapSingleTokenExactIn(pool, IERC20(tokens[0]), IERC20(tokens[1]), 0, 0, 0, false, "");

        _revertsOnNonFacadeCaller();
        adapter.swapSingleTokenDiffIn(pool, IERC20(tokens[0]), IERC20(tokens[1]), 0, 0, 0);
    }

    /// @notice U:[BAL3-3]: `swapSingleTokenExactIn` works as expected and ignores wethIsEth and userData
    function test_U_BAL3_03_swapSingleTokenExactIn_works_as_expected() public {
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(
                IBalancerV3Router.swapSingleTokenExactIn,
                (pool, IERC20(tokens[0]), IERC20(tokens[1]), 123, 456, 789, false, "")
            ),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.swapSingleTokenExactIn(
            pool,
            IERC20(tokens[0]),
            IERC20(tokens[1]),
            123,
            456,
            789,
            true, // Should be ignored and set to false
            "test" // Should be ignored and set to empty string
        );

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[BAL3-4]: `swapSingleTokenDiffIn` works as expected
    function test_U_BAL3_04_swapSingleTokenDiffIn_works_as_expected() public diffTestCases {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(
                IBalancerV3Router.swapSingleTokenExactIn,
                (pool, IERC20(tokens[0]), IERC20(tokens[1]), diffInputAmount, diffInputAmount / 2, 789, false, "")
            ),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.swapSingleTokenDiffIn(pool, IERC20(tokens[0]), IERC20(tokens[1]), diffLeftoverAmount, 0.5e27, 789);

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? 1 : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[BAL3-5]: Pool configuration works as expected
    function test_U_BAL3_05_pool_configuration_works_as_expected() public {
        address[] memory pools;
        bool[] memory statuses;

        _revertsOnNonConfiguratorCaller();
        adapter.setPoolStatusBatch(pools, statuses);

        // Test array length mismatch
        pools = new address[](2);
        pools[0] = makeAddr("POOL1");
        pools[1] = makeAddr("POOL2");
        statuses = new bool[](1);
        statuses[0] = true;

        vm.expectRevert(InvalidLengthException.selector);
        vm.prank(configurator);
        adapter.setPoolStatusBatch(pools, statuses);

        // Test setting pool statuses
        statuses = new bool[](2);
        statuses[0] = false;
        statuses[1] = true;

        vm.expectEmit(true, true, true, true);
        emit SetPoolStatus(pools[0], false);

        vm.expectEmit(true, true, true, true);
        emit SetPoolStatus(pools[1], true);

        vm.prank(configurator);
        adapter.setPoolStatusBatch(pools, statuses);

        assertFalse(adapter.isPoolAllowed(pools[0]), "First pool incorrectly allowed");
        assertTrue(adapter.isPoolAllowed(pools[1]), "Second pool incorrectly not allowed");

        // Test getAllowedPools
        address[] memory allowedPools = adapter.getAllowedPools();
        assertEq(allowedPools.length, 2, "Incorrect number of allowed pools"); // pool from setUp + pools[1]
        assertTrue(
            (allowedPools[0] == pool && allowedPools[1] == pools[1])
                || (allowedPools[0] == pools[1] && allowedPools[1] == pool),
            "Incorrect allowed pools"
        );
    }
}
