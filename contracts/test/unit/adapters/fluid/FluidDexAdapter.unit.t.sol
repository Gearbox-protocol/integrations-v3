// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {FluidDexAdapter} from "../../../../adapters/fluid/FluidDexAdapter.sol";
import {IFluidDex, ConstantViews} from "../../../../integrations/fluid/IFluidDex.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

/// @title FluidDex adapter unit test
/// @notice U:[FDEX]: Unit tests for FluidDex adapter
contract FluidDexAdapterUnitTest is AdapterUnitTestHelper {
    FluidDexAdapter adapter;

    address token0;
    address token1;
    address fluidDex;

    function setUp() public {
        _setUp();

        token0 = tokens[0];
        token1 = tokens[1];
        fluidDex = tokens[2];

        // Mock the constantsView function to return the tokens
        ConstantViews memory constantViews;
        constantViews.token0 = token0;
        constantViews.token1 = token1;
        vm.mockCall(fluidDex, abi.encodeCall(IFluidDex.constantsView, ()), abi.encode(constantViews));

        adapter = new FluidDexAdapter(address(creditManager), fluidDex);
    }

    /// @notice U:[FDEX-1]: Constructor works as expected
    function test_U_FDEX_01_constructor_works_as_expected() public {
        _readsTokenMask(token0);
        _readsTokenMask(token1);

        // Mock the constantsView function to return the tokens
        ConstantViews memory constantViews;
        constantViews.token0 = token0;
        constantViews.token1 = token1;
        vm.mockCall(fluidDex, abi.encodeCall(IFluidDex.constantsView, ()), abi.encode(constantViews));

        adapter = new FluidDexAdapter(address(creditManager), fluidDex);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), fluidDex, "Incorrect targetContract");
        assertEq(adapter.token0(), token0, "Incorrect token0");
        assertEq(adapter.token1(), token1, "Incorrect token1");
    }

    /// @notice U:[FDEX-2]: Wrapper functions revert on wrong caller
    function test_U_FDEX_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.swapIn(true, 0, 0, address(0));

        _revertsOnNonFacadeCaller();
        adapter.swapInDiff(true, 0, 0);
    }

    /// @notice U:[FDEX-3]: `swapIn()` works as expected for token0 to token1
    function test_U_FDEX_03_swapIn_works_as_expected_0to1() public {
        uint256 amountIn = 1000;
        uint256 amountOutMin = 900;
        bool swap0to1 = true;

        _readsActiveAccount();
        _executesSwap({
            tokenIn: token0,
            callData: abi.encodeCall(IFluidDex.swapIn, (swap0to1, amountIn, amountOutMin, creditAccount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.swapIn(swap0to1, amountIn, amountOutMin, address(0));
        assertTrue(useSafePrices);
    }

    /// @notice U:[FDEX-4]: `swapIn()` works as expected for token1 to token0
    function test_U_FDEX_04_swapIn_works_as_expected_1to0() public {
        uint256 amountIn = 1000;
        uint256 amountOutMin = 900;
        bool swap0to1 = false;

        _readsActiveAccount();
        _executesSwap({
            tokenIn: token1,
            callData: abi.encodeCall(IFluidDex.swapIn, (swap0to1, amountIn, amountOutMin, creditAccount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.swapIn(swap0to1, amountIn, amountOutMin, address(0));
        assertTrue(useSafePrices);
    }

    /// @notice U:[FDEX-5]: `swapInDiff()` works as expected for token0 to token1
    function test_U_FDEX_05_swapInDiff_works_as_expected_0to1() public diffTestCases {
        uint256 rateMinRAY = 9 * (RAY / 10); // 0.9 * RAY, equivalent to 90% of the input amount
        bool swap0to1 = true;
        deal({token: token0, to: creditAccount, give: diffMintedAmount});

        uint256 expectedAmountOutMin = (diffInputAmount * rateMinRAY) / RAY;

        _readsActiveAccount();
        _executesSwap({
            tokenIn: token0,
            callData: abi.encodeCall(IFluidDex.swapIn, (swap0to1, diffInputAmount, expectedAmountOutMin, creditAccount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.swapInDiff(swap0to1, diffLeftoverAmount, rateMinRAY);
        assertTrue(useSafePrices);
    }

    /// @notice U:[FDEX-6]: `swapInDiff()` works as expected for token1 to token0
    function test_U_FDEX_06_swapInDiff_works_as_expected_1to0() public diffTestCases {
        uint256 rateMinRAY = 9 * (RAY / 10); // 0.9 * RAY, equivalent to 90% of the input amount
        bool swap0to1 = false;
        deal({token: token1, to: creditAccount, give: diffMintedAmount});

        uint256 expectedAmountOutMin = (diffInputAmount * rateMinRAY) / RAY;

        _readsActiveAccount();
        _executesSwap({
            tokenIn: token1,
            callData: abi.encodeCall(IFluidDex.swapIn, (swap0to1, diffInputAmount, expectedAmountOutMin, creditAccount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.swapInDiff(swap0to1, diffLeftoverAmount, rateMinRAY);
        assertTrue(useSafePrices);
    }

    /// @notice U:[FDEX-7]: `swapInDiff()` returns false if balance <= leftoverAmount
    function test_U_FDEX_07_swapInDiff_returns_false_if_balance_too_low() public {
        uint256 balance = 1000;
        uint256 leftoverAmount = 1000; // Equal to balance
        bool swap0to1 = true;

        deal({token: token0, to: creditAccount, give: balance});

        _readsActiveAccount();
        vm.prank(creditFacade);
        bool useSafePrices = adapter.swapInDiff(swap0to1, leftoverAmount, 0);
        assertFalse(useSafePrices);

        // Test with balance less than leftoverAmount
        leftoverAmount = 1001;
        vm.prank(creditFacade);
        useSafePrices = adapter.swapInDiff(swap0to1, leftoverAmount, 0);
        assertFalse(useSafePrices);
    }
}
