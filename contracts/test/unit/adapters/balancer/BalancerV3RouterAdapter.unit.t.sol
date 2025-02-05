// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IBalancerV3Router} from "../../../../integrations/balancer/IBalancerV3Router.sol";
import {IBalancerV3Pool} from "../../../../integrations/balancer/IBalancerV3Pool.sol";
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
    address balancerPool;

    function setUp() public {
        _setUp();

        router = makeAddr("ROUTER");
        balancerPool = makeAddr("POOL");
        adapter = new BalancerV3RouterAdapter(address(creditManager), router);

        IERC20[] memory poolTokens = new IERC20[](2);
        poolTokens[0] = IERC20(tokens[0]);
        poolTokens[1] = IERC20(tokens[1]);

        // Mock pool token retrieval
        vm.mockCall(balancerPool, abi.encodeCall(IBalancerV3Pool.getTokens, ()), abi.encode(poolTokens));

        // Set pool as allowed
        address[] memory pools = new address[](1);
        pools[0] = balancerPool;
        bool[] memory statuses = new bool[](1);
        statuses[0] = true;
        vm.prank(configurator);
        adapter.setPoolStatusBatch(pools, statuses);
    }

    /// @notice U:[BAL3-1]: Constructor works as expected
    function test_U_BAL3_01_constructor_works_as_expected() public {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), router, "Incorrect targetContract");
    }

    /// @notice U:[BAL3-2]: Wrapper functions revert on wrong caller
    function test_U_BAL3_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.swapSingleTokenExactIn(balancerPool, IERC20(tokens[0]), IERC20(tokens[1]), 0, 0, 0, false, "");

        _revertsOnNonFacadeCaller();
        adapter.swapSingleTokenDiffIn(balancerPool, IERC20(tokens[0]), IERC20(tokens[1]), 0, 0, 0);
    }

    /// @notice U:[BAL3-3]: `swapSingleTokenExactIn` works as expected and ignores wethIsEth and userData
    function test_U_BAL3_03_swapSingleTokenExactIn_works_as_expected() public {
        // Check that non-allowed pool reverts
        address nonAllowedPool = makeAddr("NON_ALLOWED_POOL");
        vm.expectRevert(InvalidPoolException.selector);
        vm.prank(creditFacade);
        adapter.swapSingleTokenExactIn(nonAllowedPool, IERC20(tokens[0]), IERC20(tokens[1]), 0, 0, 0, false, "");

        // Check that allowed pool works
        _executesSwap({
            tokenIn: tokens[0],
            callData: abi.encodeCall(
                IBalancerV3Router.swapSingleTokenExactIn,
                (balancerPool, IERC20(tokens[0]), IERC20(tokens[1]), 123, 456, 789, false, "")
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.swapSingleTokenExactIn(
            balancerPool,
            IERC20(tokens[0]),
            IERC20(tokens[1]),
            123,
            456,
            789,
            true, // Should be ignored and set to false
            "test" // Should be ignored and set to empty string
        );

        assertTrue(useSafePrices, "Should use safe prices");
    }

    /// @notice U:[BAL3-4]: `swapSingleTokenDiffIn` works as expected
    function test_U_BAL3_04_swapSingleTokenDiffIn_works_as_expected() public diffTestCases {
        // Check that non-allowed pool reverts
        address nonAllowedPool = makeAddr("NON_ALLOWED_POOL");
        vm.expectRevert(InvalidPoolException.selector);
        vm.prank(creditFacade);
        adapter.swapSingleTokenDiffIn(nonAllowedPool, IERC20(tokens[0]), IERC20(tokens[1]), 0, 0, 0);

        // Check that allowed pool works
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        _executesSwap({
            tokenIn: tokens[0],
            callData: abi.encodeCall(
                IBalancerV3Router.swapSingleTokenExactIn,
                (balancerPool, IERC20(tokens[0]), IERC20(tokens[1]), diffInputAmount, diffInputAmount / 2, 789, false, "")
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.swapSingleTokenDiffIn(
            balancerPool, IERC20(tokens[0]), IERC20(tokens[1]), diffLeftoverAmount, 0.5e27, 789
        );

        assertTrue(useSafePrices, "Should use safe prices");
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

        // Mock pool token retrieval for new pools
        IERC20[] memory pool1Tokens = new IERC20[](2);
        pool1Tokens[0] = IERC20(tokens[0]);
        pool1Tokens[1] = IERC20(tokens[1]);
        vm.mockCall(pools[0], abi.encodeCall(IBalancerV3Pool.getTokens, ()), abi.encode(pool1Tokens));

        IERC20[] memory pool2Tokens = new IERC20[](2);
        pool2Tokens[0] = IERC20(tokens[1]);
        pool2Tokens[1] = IERC20(tokens[2]);
        vm.mockCall(pools[1], abi.encodeCall(IBalancerV3Pool.getTokens, ()), abi.encode(pool2Tokens));

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
        assertEq(allowedPools.length, 2, "Incorrect number of allowed pools"); // balancerPool from setUp + pools[1]
        assertTrue(
            (allowedPools[0] == balancerPool && allowedPools[1] == pools[1])
                || (allowedPools[0] == pools[1] && allowedPools[1] == balancerPool),
            "Incorrect allowed pools"
        );
    }
}
