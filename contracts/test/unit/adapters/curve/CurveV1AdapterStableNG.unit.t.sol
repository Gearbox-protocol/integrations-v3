// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {CurveV1AdapterStableNG} from "../../../../adapters/curve/CurveV1_StableNG.sol";
import {ICurvePoolStableNG} from "../../../../integrations/curve/ICurvePool_StableNG.sol";
import {PoolMock, PoolType} from "../../../mocks/integrations/curve/PoolMock.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Curve Stable NG unit test
/// @notice U:[CRVNG]: Unit tests for Curve StableNG pool adapter
contract CurveV1AdapterStablNGUnitTest is AdapterUnitTestHelper {
    CurveV1AdapterStableNG adapter;
    PoolMock curvePool;

    address token0;
    address token1;
    address token2;
    address lpToken;

    function setUp() public {
        _setUp();

        token0 = tokens[0];
        token1 = tokens[1];
        token2 = tokens[2];
        lpToken = tokens[3];

        address[] memory coins = new address[](3);
        coins[0] = token0;
        coins[1] = token1;
        coins[2] = token2;
        curvePool = new PoolMock(PoolType.Stable, coins, new address[](0));

        adapter = new CurveV1AdapterStableNG(address(creditManager), address(curvePool), lpToken, address(0), false);

        assertEq(adapter.nCoins(), 3, "Incorrect nCoins");
    }

    /// @notice U:[CRVNG-1]: Wrapper functions revert on wrong caller
    function test_U_CRVNG_01_wrapper_functions_revert_on_wrong_caller() public {
        uint256[] memory amounts;

        _revertsOnNonFacadeCaller();
        adapter.add_liquidity(amounts, 0);

        _revertsOnNonFacadeCaller();
        adapter.remove_liquidity(0, amounts);

        _revertsOnNonFacadeCaller();
        adapter.remove_liquidity_imbalance(amounts, 0);
    }

    /// @notice U:[CRVNG-2]: `add_liquidity` works as expected
    function test_U_CRVNG_02_add_liquidity_works_as_expected() public {
        address[] memory tokensToApprove = new address[](2);
        tokensToApprove[0] = token0;
        tokensToApprove[1] = token1;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 750;
        amounts[1] = 250;
        amounts[2] = 125;

        _executesCall({
            tokensToApprove: tokensToApprove,
            callData: abi.encodeCall(ICurvePoolStableNG.add_liquidity, (amounts, 500))
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.add_liquidity(amounts, 500);
        assertTrue(useSafePrices);
    }

    /// @notice U:[CRVNG-3]: `remove_liquidity` works as expected
    function test_U_CRVNG_03_remove_liquidity_works_as_expected() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 750;
        amounts[1] = 250;
        amounts[2] = 125;

        _executesCall({
            tokensToApprove: new address[](0),
            callData: abi.encodeCall(ICurvePoolStableNG.remove_liquidity, (500, amounts))
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.remove_liquidity(500, amounts);
        assertTrue(useSafePrices);
    }

    /// @notice U:[CRVNG-4]: `remove_liquidity_imbalance` works as expected
    function test_U_CRVNG_04_remove_liquidity_imbalance_works_as_expected() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 750;
        amounts[1] = 0;
        amounts[2] = 125;

        _executesCall({
            tokensToApprove: new address[](0),
            callData: abi.encodeCall(ICurvePoolStableNG.remove_liquidity_imbalance, (amounts, 500))
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.remove_liquidity_imbalance(amounts, 500);
        assertTrue(useSafePrices);
    }
}
