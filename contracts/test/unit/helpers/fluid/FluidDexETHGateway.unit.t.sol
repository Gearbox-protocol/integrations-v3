// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "@gearbox-protocol/core-v3/contracts/interfaces/external/IWETH.sol";
import {ZeroAddressException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {FluidDexETHGateway} from "../../../../helpers/fluid/FluidDexETHGateway.sol";
import {IFluidDex, ConstantViews, Implementations} from "../../../../integrations/fluid/IFluidDex.sol";

/// @title FluidDexETHGateway unit test
/// @notice U:[FDEXG]: Unit tests for FluidDexETHGateway
contract FluidDexETHGatewayTest is Test {
    FluidDexETHGateway gateway;

    address mockPool;
    address mockWETH;
    address mockToken;
    address user;

    // Special ETH address used by Fluid
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 constant AMOUNT_IN = 1 ether;
    uint256 constant AMOUNT_OUT = 0.95 ether;
    uint256 constant MIN_AMOUNT_OUT = 0.9 ether;

    function setUp() public {
        mockPool = makeAddr("mockPool");
        mockWETH = makeAddr("mockWETH");
        mockToken = makeAddr("mockToken");
        user = makeAddr("user");

        // Mock constantsView call
        ConstantViews memory views;
        Implementations memory implementations;
        views.token0 = ETH;
        views.token1 = mockToken;
        views.implementations = implementations;
        vm.mockCall(mockPool, abi.encodeCall(IFluidDex.constantsView, ()), abi.encode(views));
        vm.mockCall(mockToken, abi.encodeCall(IERC20.approve, (mockPool, type(uint256).max)), abi.encode(true));

        gateway = new FluidDexETHGateway(mockPool, mockWETH);
    }

    /// @notice U:[FDEXG-1]: Constructor works as expected
    function test_U_FDEXG_01_constructor_works_as_expected() public {
        assertEq(gateway.pool(), mockPool, "Incorrect pool address");
        assertEq(gateway.weth(), mockWETH, "Incorrect WETH address");
        assertEq(gateway.otherToken(), mockToken, "Incorrect other token address");
        assertTrue(gateway.ethIsToken0(), "ETH should be token0");

        // Test with ETH as token1
        ConstantViews memory views;
        Implementations memory implementations;
        views.token0 = mockToken;
        views.token1 = ETH;
        views.implementations = implementations;
        vm.mockCall(mockPool, abi.encodeCall(IFluidDex.constantsView, ()), abi.encode(views));

        FluidDexETHGateway gateway2 = new FluidDexETHGateway(mockPool, mockWETH);
        assertEq(gateway2.pool(), mockPool, "Incorrect pool address");
        assertEq(gateway2.weth(), mockWETH, "Incorrect WETH address");
        assertEq(gateway2.otherToken(), mockToken, "Incorrect other token address");
        assertFalse(gateway2.ethIsToken0(), "ETH should be token1");
    }

    /// @notice U:[FDEXG-2]: Constructor reverts on zero addresses
    function test_U_FDEXG_02_constructor_reverts_on_zero_addresses() public {
        vm.expectRevert(ZeroAddressException.selector);
        new FluidDexETHGateway(address(0), mockWETH);

        vm.expectRevert(ZeroAddressException.selector);
        new FluidDexETHGateway(mockPool, address(0));
    }

    /// @notice U:[FDEXG-3]: Constructor reverts when pool doesn't contain ETH
    function test_U_FDEXG_03_constructor_reverts_when_pool_doesnt_contain_eth() public {
        ConstantViews memory views;
        Implementations memory implementations;
        views.token0 = makeAddr("randomToken1");
        views.token1 = makeAddr("randomToken2");
        views.implementations = implementations;
        vm.mockCall(mockPool, abi.encodeCall(IFluidDex.constantsView, ()), abi.encode(views));

        vm.expectRevert("Pool does not contain ETH");
        new FluidDexETHGateway(mockPool, mockWETH);
    }

    /// @notice U:[FDEXG-4]: constantsView returns correct values
    function test_U_FDEXG_04_constantsView_returns_correct_values() public {
        // Mock the original pool's constantsView
        ConstantViews memory views;
        Implementations memory implementations;
        views.token0 = ETH;
        views.token1 = mockToken;
        views.dexId = 123;
        views.implementations = implementations;
        vm.mockCall(mockPool, abi.encodeCall(IFluidDex.constantsView, ()), abi.encode(views));

        ConstantViews memory returnedViews = gateway.constantsView();
        assertEq(returnedViews.token0, mockWETH, "Incorrect token0 - should be WETH");
        assertEq(returnedViews.token1, mockToken, "Incorrect token1");
        assertEq(returnedViews.dexId, 123, "Incorrect dexId");
    }

    /// @notice U:[FDEXG-5]: swapIn works for WETH to token
    function test_U_FDEXG_05_swapIn_works_for_weth_to_token() public {
        bool swap0to1 = true; // ETH/WETH to token

        // Mock token transfers
        vm.mockCall(
            mockWETH, abi.encodeCall(IERC20.transferFrom, (user, address(gateway), AMOUNT_IN)), abi.encode(true)
        );

        // Mock WETH withdraw
        vm.mockCall(mockWETH, abi.encodeCall(IWETH.withdraw, (AMOUNT_IN)), abi.encode());

        // Mock pool swap
        vm.mockCall(
            mockPool,
            abi.encodeCall(IFluidDex.swapIn, (swap0to1, AMOUNT_IN, MIN_AMOUNT_OUT, user)),
            abi.encode(AMOUNT_OUT)
        );

        vm.prank(user);
        uint256 amountOut = gateway.swapIn(swap0to1, AMOUNT_IN, MIN_AMOUNT_OUT, user);

        assertEq(amountOut, AMOUNT_OUT, "Incorrect amount out");
    }

    /// @notice U:[FDEXG-6]: swapIn works for token to WETH
    function test_U_FDEXG_06_swapIn_works_for_token_to_weth() public {
        bool swap0to1 = false; // token to ETH/WETH

        // Mock token transfers
        vm.mockCall(
            mockToken, abi.encodeCall(IERC20.transferFrom, (user, address(gateway), AMOUNT_IN)), abi.encode(true)
        );

        // Mock pool swap
        vm.mockCall(
            mockPool,
            abi.encodeCall(IFluidDex.swapIn, (swap0to1, AMOUNT_IN, MIN_AMOUNT_OUT, address(gateway))),
            abi.encode(AMOUNT_OUT)
        );

        // Mock WETH deposit
        vm.mockCall(mockWETH, abi.encodeCall(IWETH.deposit, ()), abi.encode());

        // Mock WETH balance check
        vm.mockCall(mockWETH, abi.encodeCall(IERC20.balanceOf, (address(gateway))), abi.encode(AMOUNT_OUT));

        // Mock WETH transfer with 1 wei less for gas savings
        uint256 transferAmount = AMOUNT_OUT - 1;
        vm.mockCall(mockWETH, abi.encodeCall(IERC20.transfer, (user, transferAmount)), abi.encode(true));

        vm.prank(user);
        uint256 amountOut = gateway.swapIn(swap0to1, AMOUNT_IN, MIN_AMOUNT_OUT, user);

        assertEq(amountOut, AMOUNT_OUT, "Incorrect amount out");
    }

    /// @notice U:[FDEXG-7]: swapIn works with ETH as token1
    function test_U_FDEXG_07_swapIn_works_with_eth_as_token1() public {
        // Recreate gateway with ETH as token1
        ConstantViews memory views;
        Implementations memory implementations;
        views.token0 = mockToken;
        views.token1 = ETH;
        views.implementations = implementations;
        vm.mockCall(mockPool, abi.encodeCall(IFluidDex.constantsView, ()), abi.encode(views));

        FluidDexETHGateway gateway2 = new FluidDexETHGateway(mockPool, mockWETH);

        // Test swap from WETH to token (swap1to0)
        bool swap0to1 = false; // token1 to token0 (ETH/WETH to token)

        // Mock token transfers
        vm.mockCall(
            mockWETH, abi.encodeCall(IERC20.transferFrom, (user, address(gateway2), AMOUNT_IN)), abi.encode(true)
        );

        // Mock WETH withdraw
        vm.mockCall(mockWETH, abi.encodeCall(IWETH.withdraw, (AMOUNT_IN)), abi.encode());

        // Mock pool swap
        vm.mockCall(
            mockPool,
            abi.encodeCall(IFluidDex.swapIn, (swap0to1, AMOUNT_IN, MIN_AMOUNT_OUT, user)),
            abi.encode(AMOUNT_OUT)
        );

        vm.prank(user);
        uint256 amountOut = gateway2.swapIn(swap0to1, AMOUNT_IN, MIN_AMOUNT_OUT, user);

        assertEq(amountOut, AMOUNT_OUT, "Incorrect amount out");
    }

    /// @notice U:[FDEXG-8]: transferAllTokensOf works with different balances
    function test_U_FDEXG_08_transferAllTokensOf_works_with_different_balances() public {
        bool swap0to1 = false; // token to ETH/WETH

        // Test case 1: Zero balance
        // Mock token transfers
        vm.mockCall(
            mockToken, abi.encodeCall(IERC20.transferFrom, (user, address(gateway), AMOUNT_IN)), abi.encode(true)
        );

        // Mock pool swap
        vm.mockCall(
            mockPool,
            abi.encodeCall(IFluidDex.swapIn, (swap0to1, AMOUNT_IN, MIN_AMOUNT_OUT, address(gateway))),
            abi.encode(AMOUNT_OUT)
        );

        // Mock WETH deposit
        vm.mockCall(mockWETH, abi.encodeCall(IWETH.deposit, ()), abi.encode());

        // Mock WETH balance check - zero balance
        vm.mockCall(mockWETH, abi.encodeCall(IERC20.balanceOf, (address(gateway))), abi.encode(0));

        // No transfer should happen with zero balance
        vm.prank(user);
        gateway.swapIn(swap0to1, AMOUNT_IN, MIN_AMOUNT_OUT, user);

        // Test case 2: 1 wei balance
        // Mock WETH balance check - 1 wei balance
        vm.mockCall(mockWETH, abi.encodeCall(IERC20.balanceOf, (address(gateway))), abi.encode(1));

        // No transfer should happen with 1 wei balance
        vm.prank(user);
        gateway.swapIn(swap0to1, AMOUNT_IN, MIN_AMOUNT_OUT, user);

        // Test case 3: Normal balance
        uint256 balance = 1000;
        vm.mockCall(mockWETH, abi.encodeCall(IERC20.balanceOf, (address(gateway))), abi.encode(balance));

        // Should transfer balance - 1
        uint256 transferAmount = balance - 1;
        vm.mockCall(mockWETH, abi.encodeCall(IERC20.transfer, (user, transferAmount)), abi.encode(true));

        vm.prank(user);
        gateway.swapIn(swap0to1, AMOUNT_IN, MIN_AMOUNT_OUT, user);
    }

    receive() external payable {}
}
