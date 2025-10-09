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
    IBalancerV3RouterAdapterExceptions,
    BalancerV3PoolStatus,
    PoolStatus
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
        balancerPool = tokens[2];
        adapter = new BalancerV3RouterAdapter(address(creditManager), router);

        IERC20[] memory poolTokens = new IERC20[](2);
        poolTokens[0] = IERC20(tokens[0]);
        poolTokens[1] = IERC20(tokens[1]);

        // Mock pool token retrieval
        vm.mockCall(balancerPool, abi.encodeCall(IBalancerV3Pool.getTokens, ()), abi.encode(poolTokens));

        // Set pool as allowed
        BalancerV3PoolStatus[] memory pools = new BalancerV3PoolStatus[](1);
        pools[0] = BalancerV3PoolStatus({pool: balancerPool, status: PoolStatus.ALLOWED});
        vm.prank(configurator);
        adapter.setPoolStatusBatch(pools);
    }

    /// @notice U:[BAL3-1]: Constructor works as expected
    function test_U_BAL3_01_constructor_works_as_expected() public view {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), router, "Incorrect targetContract");
    }

    /// @notice U:[BAL3-2]: Wrapper functions revert on wrong caller
    function test_U_BAL3_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.swapSingleTokenExactIn(balancerPool, IERC20(tokens[0]), IERC20(tokens[1]), 0, 0, 0, false, "");

        _revertsOnNonFacadeCaller();
        adapter.swapSingleTokenDiffIn(balancerPool, IERC20(tokens[0]), IERC20(tokens[1]), 0, 0, 0);

        uint256[] memory amounts = new uint256[](0);
        _revertsOnNonFacadeCaller();
        adapter.addLiquidityUnbalanced(balancerPool, amounts, 0, false, "");

        _revertsOnNonFacadeCaller();
        adapter.addLiquidityUnbalancedDiff(balancerPool, amounts, amounts);

        _revertsOnNonFacadeCaller();
        adapter.removeLiquiditySingleTokenExactIn(balancerPool, 0, IERC20(tokens[0]), 0, false, "");

        _revertsOnNonFacadeCaller();
        adapter.removeLiquiditySingleTokenDiff(balancerPool, 0, IERC20(tokens[0]), 0);
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

    /// @notice U:[BAL3-5]: `addLiquidityUnbalanced` works as expected
    function test_U_BAL3_05_addLiquidityUnbalanced_works_as_expected() public {
        // Check that non-allowed pool reverts
        address nonAllowedPool = makeAddr("NON_ALLOWED_POOL");
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        vm.expectRevert(InvalidPoolException.selector);
        vm.prank(creditFacade);
        adapter.addLiquidityUnbalanced(nonAllowedPool, amounts, 0, false, "");

        // Check length mismatch
        uint256[] memory wrongAmounts = new uint256[](3);
        vm.expectRevert(InvalidLengthException.selector);
        vm.prank(creditFacade);
        adapter.addLiquidityUnbalanced(balancerPool, wrongAmounts, 0, false, "");

        // Check that allowed pool works
        // Set up tokens to approve
        address[] memory tokensToApprove = new address[](2);
        tokensToApprove[0] = tokens[0];
        tokensToApprove[1] = tokens[1];

        _executesCall(
            tokensToApprove,
            abi.encodeCall(IBalancerV3Router.addLiquidityUnbalanced, (balancerPool, amounts, 300, false, ""))
        );

        vm.prank(creditFacade);
        bool useSafePrices = adapter.addLiquidityUnbalanced(
            balancerPool,
            amounts,
            300,
            true, // Should be ignored
            "test" // Should be ignored
        );

        assertTrue(useSafePrices, "Should use safe prices");
    }

    /// @notice U:[BAL3-6]: `addLiquidityUnbalancedDiff` works as expected
    function test_U_BAL3_06_addLiquidityUnbalancedDiff_works_as_expected() public diffTestCases {
        // Setup balances
        deal({token: tokens[0], to: creditAccount, give: 1000});
        deal({token: tokens[1], to: creditAccount, give: 2000});

        uint256[] memory leftoverAmounts = new uint256[](2);
        leftoverAmounts[0] = 100;
        leftoverAmounts[1] = 200;

        uint256[] memory minRatesRAY = new uint256[](2);
        minRatesRAY[0] = 0.1e27; // 10%
        minRatesRAY[1] = 0.2e27; // 20%

        // Check that non-allowed pool reverts
        address nonAllowedPool = makeAddr("NON_ALLOWED_POOL");
        vm.expectRevert(InvalidPoolException.selector);
        vm.prank(creditFacade);
        adapter.addLiquidityUnbalancedDiff(nonAllowedPool, leftoverAmounts, minRatesRAY);

        // Check length mismatches
        uint256[] memory wrongAmounts = new uint256[](3);
        vm.expectRevert(InvalidLengthException.selector);
        vm.prank(creditFacade);
        adapter.addLiquidityUnbalancedDiff(balancerPool, wrongAmounts, minRatesRAY);

        vm.expectRevert(InvalidLengthException.selector);
        vm.prank(creditFacade);
        adapter.addLiquidityUnbalancedDiff(balancerPool, leftoverAmounts, wrongAmounts);

        // Check that allowed pool works
        _readsActiveAccount();

        uint256[] memory expectedAmounts = new uint256[](2);
        expectedAmounts[0] = 900; // 1000 - 100
        expectedAmounts[1] = 1800; // 2000 - 200
        uint256 expectedMinBpt = 90 + 360; // (900 * 0.1e27 / 1e27) + (1800 * 0.2e27 / 1e27) = 90 + 360 = 450

        // Set up tokens to approve
        address[] memory tokensToApprove = new address[](2);
        tokensToApprove[0] = tokens[0];
        tokensToApprove[1] = tokens[1];

        _executesCall(
            tokensToApprove,
            abi.encodeCall(
                IBalancerV3Router.addLiquidityUnbalanced, (balancerPool, expectedAmounts, expectedMinBpt, false, "")
            )
        );

        vm.prank(creditFacade);
        bool useSafePrices = adapter.addLiquidityUnbalancedDiff(balancerPool, leftoverAmounts, minRatesRAY);

        assertTrue(useSafePrices, "Should use safe prices");
    }

    /// @notice U:[BAL3-7]: `removeLiquiditySingleTokenExactIn` works as expected
    function test_U_BAL3_07_removeLiquiditySingleTokenExactIn_works_as_expected() public {
        // Check that non-allowed pool reverts
        address nonAllowedPool = makeAddr("NON_ALLOWED_POOL");
        vm.expectRevert(InvalidPoolException.selector);
        vm.prank(creditFacade);
        adapter.removeLiquiditySingleTokenExactIn(nonAllowedPool, 100, IERC20(tokens[0]), 50, false, "");

        // Check that allowed pool works
        _executesSwap({
            tokenIn: balancerPool,
            callData: abi.encodeCall(
                IBalancerV3Router.removeLiquiditySingleTokenExactIn, (balancerPool, 100, IERC20(tokens[0]), 50, false, "")
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.removeLiquiditySingleTokenExactIn(
            balancerPool,
            100,
            IERC20(tokens[0]),
            50,
            true, // Should be ignored
            "test" // Should be ignored
        );

        assertTrue(useSafePrices, "Should use safe prices");
    }

    /// @notice U:[BAL3-8]: `removeLiquiditySingleTokenDiff` works as expected
    function test_U_BAL3_08_removeLiquiditySingleTokenDiff_works_as_expected() public diffTestCases {
        // Mock balanceOf for the pool token
        vm.mockCall(balancerPool, abi.encodeCall(IERC20.balanceOf, (creditAccount)), abi.encode(diffMintedAmount));

        // Check that non-allowed pool reverts
        address nonAllowedPool = makeAddr("NON_ALLOWED_POOL");
        vm.expectRevert(InvalidPoolException.selector);
        vm.prank(creditFacade);
        adapter.removeLiquiditySingleTokenDiff(nonAllowedPool, diffLeftoverAmount, IERC20(tokens[0]), 0.5e27);

        // Check that allowed pool works
        _readsActiveAccount();
        _executesSwap({
            tokenIn: balancerPool,
            callData: abi.encodeCall(
                IBalancerV3Router.removeLiquiditySingleTokenExactIn,
                (balancerPool, diffInputAmount, IERC20(tokens[0]), diffInputAmount / 2, false, "")
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices =
            adapter.removeLiquiditySingleTokenDiff(balancerPool, diffLeftoverAmount, IERC20(tokens[0]), 0.5e27);

        assertTrue(useSafePrices, "Should use safe prices");
    }

    /// @notice U:[BAL3-9]: Pool configuration works as expected
    function test_U_BAL3_09_pool_configuration_works_as_expected() public {
        BalancerV3PoolStatus[] memory pools;

        _revertsOnNonConfiguratorCaller();
        adapter.setPoolStatusBatch(pools);

        // Create test pools
        address pool1 = makeAddr("POOL1");
        address pool2 = makeAddr("POOL2");
        address pool3 = makeAddr("POOL3");

        // Mock pool token retrieval for new pools
        IERC20[] memory pool1Tokens = new IERC20[](2);
        pool1Tokens[0] = IERC20(tokens[0]);
        pool1Tokens[1] = IERC20(tokens[1]);
        vm.mockCall(pool1, abi.encodeCall(IBalancerV3Pool.getTokens, ()), abi.encode(pool1Tokens));

        IERC20[] memory pool2Tokens = new IERC20[](2);
        pool2Tokens[0] = IERC20(tokens[1]);
        pool2Tokens[1] = IERC20(tokens[2]);
        vm.mockCall(pool2, abi.encodeCall(IBalancerV3Pool.getTokens, ()), abi.encode(pool2Tokens));

        IERC20[] memory pool3Tokens = new IERC20[](2);
        pool3Tokens[0] = IERC20(tokens[0]);
        pool3Tokens[1] = IERC20(tokens[2]);
        vm.mockCall(pool3, abi.encodeCall(IBalancerV3Pool.getTokens, ()), abi.encode(pool3Tokens));

        // Add pool masks
        creditManager.setMask(pool1, 1 << 11);
        creditManager.setMask(pool2, 1 << 12);
        creditManager.setMask(pool3, 1 << 13);

        // Test setting pool statuses with different types
        pools = new BalancerV3PoolStatus[](3);
        pools[0] = BalancerV3PoolStatus({pool: pool1, status: PoolStatus.NOT_ALLOWED});
        pools[1] = BalancerV3PoolStatus({pool: pool2, status: PoolStatus.SWAP_ONLY});
        pools[2] = BalancerV3PoolStatus({pool: pool3, status: PoolStatus.EXIT_ONLY});

        vm.expectEmit(true, true, true, true);
        emit SetPoolStatus(pool1, PoolStatus.NOT_ALLOWED);

        vm.expectEmit(true, true, true, true);
        emit SetPoolStatus(pool2, PoolStatus.SWAP_ONLY);

        vm.expectEmit(true, true, true, true);
        emit SetPoolStatus(pool3, PoolStatus.EXIT_ONLY);

        vm.prank(configurator);
        adapter.setPoolStatusBatch(pools);

        assertEq(uint256(adapter.poolStatus(pool1)), uint256(PoolStatus.NOT_ALLOWED), "Pool1 status incorrect");
        assertEq(uint256(adapter.poolStatus(pool2)), uint256(PoolStatus.SWAP_ONLY), "Pool2 status incorrect");
        assertEq(uint256(adapter.poolStatus(pool3)), uint256(PoolStatus.EXIT_ONLY), "Pool3 status incorrect");

        // Test that swap is allowed for SWAP_ONLY pool but not deposit/exit
        vm.prank(creditFacade);
        vm.expectRevert(InvalidPoolException.selector);
        adapter.addLiquidityUnbalanced(pool2, new uint256[](2), 0, false, "");

        vm.prank(creditFacade);
        vm.expectRevert(InvalidPoolException.selector);
        adapter.removeLiquiditySingleTokenExactIn(pool2, 100, IERC20(tokens[0]), 50, false, "");

        // Test that exit is allowed for EXIT_ONLY pool but not swap/deposit
        vm.prank(creditFacade);
        vm.expectRevert(InvalidPoolException.selector);
        adapter.swapSingleTokenExactIn(pool3, IERC20(tokens[0]), IERC20(tokens[1]), 100, 50, 0, false, "");

        vm.prank(creditFacade);
        vm.expectRevert(InvalidPoolException.selector);
        adapter.addLiquidityUnbalanced(pool3, new uint256[](2), 0, false, "");

        // Test getAllowedPools
        BalancerV3PoolStatus[] memory allowedPools = adapter.getAllowedPools();
        assertEq(allowedPools.length, 3, "Incorrect number of allowed pools"); // balancerPool + pool2 + pool3

        // Verify that NOT_ALLOWED pool is not in the list
        for (uint256 i = 0; i < allowedPools.length; i++) {
            assertTrue(allowedPools[i].pool != pool1, "NOT_ALLOWED pool should not be in getAllowedPools");
        }
    }
}
