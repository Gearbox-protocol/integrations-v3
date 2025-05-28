// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {IWETH} from "@gearbox-protocol/core-v3/contracts/interfaces/external/IWETH.sol";
import {ZeroAddressException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {FluidDexETHGateway} from "../../../../helpers/fluid/FluidDexETHGateway.sol";
import {IFluidDex, ConstantViews, Implementations} from "../../../../integrations/fluid/IFluidDex.sol";
import {WETHMock} from "../../../mocks/token/WETHMock.sol";

/// @title Mock FluidDex pool contract for testing
contract FluidDexPoolMock is IFluidDex {
    address public immutable token0;
    address public immutable token1;
    uint256 public immutable dexId;

    // Exchange rate: 1 ETH = exchangeRate tokens (scaled by 1e18)
    uint256 public exchangeRate = 1e18; // 1:1 by default

    // Special ETH address used by Fluid
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor(address _token0, address _token1, uint256 _dexId) {
        token0 = _token0;
        token1 = _token1;
        dexId = _dexId;
    }

    function setExchangeRate(uint256 _rate) external {
        exchangeRate = _rate;
    }

    function swapIn(bool swap0to1, uint256 amountIn, uint256, address to)
        external
        payable
        returns (uint256 amountOut)
    {
        if (swap0to1) {
            if (token0 == ETH) {
                require(msg.value == amountIn, "ETH amount mismatch");
                amountOut = (amountIn * exchangeRate) / 1e18;
                IERC20(token1).transfer(to, amountOut);
            } else {
                IERC20(token0).transferFrom(msg.sender, address(this), amountIn);
                amountOut = (amountIn * exchangeRate) / 1e18;
                payable(to).transfer(amountOut);
            }
        } else {
            if (token1 == ETH) {
                require(msg.value == amountIn, "ETH amount mismatch");
                amountOut = (amountIn * 1e18) / exchangeRate;
                IERC20(token0).transfer(to, amountOut);
            } else {
                IERC20(token1).transferFrom(msg.sender, address(this), amountIn);
                amountOut = (amountIn * 1e18) / exchangeRate;
                payable(to).transfer(amountOut);
            }
        }
    }

    function constantsView() external view returns (ConstantViews memory) {
        ConstantViews memory views;
        views.token0 = token0;
        views.token1 = token1;
        views.dexId = dexId;
        return views;
    }

    receive() external payable {}
}

/// @title FluidDexETHGateway unit test
/// @notice U:[FDEXG]: Unit tests for FluidDexETHGateway
contract FluidDexETHGatewayTest is Test {
    FluidDexETHGateway gateway;
    FluidDexPoolMock pool;
    WETHMock weth;
    ERC20Mock otherToken;

    address user;

    // Special ETH address used by Fluid
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 constant AMOUNT_IN = 1 ether;
    uint256 constant AMOUNT_OUT = 0.95 ether;
    uint256 constant MIN_AMOUNT_OUT = 0.9 ether;
    uint256 constant EXCHANGE_RATE = 0.95e18; // 1 ETH = 0.95 tokens

    function setUp() public {
        user = makeAddr("user");

        // Deploy mock contracts
        weth = new WETHMock();
        otherToken = new ERC20Mock("TestToken", "TEST", 18);
        pool = new FluidDexPoolMock(ETH, address(otherToken), 123);

        // Set exchange rate
        pool.setExchangeRate(EXCHANGE_RATE);

        // Fund the pool with ETH for swaps
        vm.deal(address(pool), 100 ether);

        // Deploy gateway
        gateway = new FluidDexETHGateway(address(pool), address(weth));

        // Fund user with tokens
        vm.deal(user, 10 ether);

        vm.prank(user);
        weth.deposit{value: 10 ether}();

        otherToken.mint(user, 10 ether);
        otherToken.mint(address(pool), 100 ether);
    }

    /// @notice U:[FDEXG-1]: Constructor works as expected
    function test_U_FDEXG_01_constructor_works_as_expected() public {
        assertEq(gateway.pool(), address(pool), "Incorrect pool address");
        assertEq(gateway.weth(), address(weth), "Incorrect WETH address");
        assertEq(gateway.otherToken(), address(otherToken), "Incorrect other token address");
        assertTrue(gateway.ethIsToken0(), "ETH should be token0");

        // Test with ETH as token1
        FluidDexPoolMock pool2 = new FluidDexPoolMock(address(otherToken), ETH, 456);
        FluidDexETHGateway gateway2 = new FluidDexETHGateway(address(pool2), address(weth));

        assertEq(gateway2.pool(), address(pool2), "Incorrect pool address");
        assertEq(gateway2.weth(), address(weth), "Incorrect WETH address");
        assertEq(gateway2.otherToken(), address(otherToken), "Incorrect other token address");
        assertFalse(gateway2.ethIsToken0(), "ETH should be token1");
    }

    /// @notice U:[FDEXG-2]: Constructor reverts on zero addresses
    function test_U_FDEXG_02_constructor_reverts_on_zero_addresses() public {
        vm.expectRevert(ZeroAddressException.selector);
        new FluidDexETHGateway(address(0), address(weth));

        vm.expectRevert(ZeroAddressException.selector);
        new FluidDexETHGateway(address(pool), address(0));
    }

    /// @notice U:[FDEXG-3]: Constructor reverts when pool doesn't contain ETH
    function test_U_FDEXG_03_constructor_reverts_when_pool_doesnt_contain_eth() public {
        ERC20Mock randomToken1 = new ERC20Mock("TestToken", "TEST", 18);
        ERC20Mock randomToken2 = new ERC20Mock("TestToken", "TEST", 18);
        FluidDexPoolMock invalidPool = new FluidDexPoolMock(address(randomToken1), address(randomToken2), 789);

        vm.expectRevert("Pool does not contain ETH");
        new FluidDexETHGateway(address(invalidPool), address(weth));
    }

    /// @notice U:[FDEXG-4]: constantsView returns correct values
    function test_U_FDEXG_04_constantsView_returns_correct_values() public {
        ConstantViews memory returnedViews = gateway.constantsView();
        assertEq(returnedViews.token0, address(weth), "Incorrect token0 - should be WETH");
        assertEq(returnedViews.token1, address(otherToken), "Incorrect token1");
        assertEq(returnedViews.dexId, 123, "Incorrect dexId");
    }

    /// @notice U:[FDEXG-5]: swapIn works for WETH to token
    function test_U_FDEXG_05_swapIn_works_for_weth_to_token() public {
        bool swap0to1 = true; // ETH/WETH to token

        // Approve gateway to spend WETH
        vm.prank(user);
        weth.approve(address(gateway), AMOUNT_IN);

        uint256 userWethBalanceBefore = weth.balanceOf(user);
        uint256 userTokenBalanceBefore = otherToken.balanceOf(user);

        vm.prank(user);
        uint256 amountOut = gateway.swapIn(swap0to1, AMOUNT_IN, MIN_AMOUNT_OUT, user);

        uint256 expectedAmountOut = (AMOUNT_IN * EXCHANGE_RATE) / 1e18;
        assertEq(amountOut, expectedAmountOut, "Incorrect amount out");
        assertEq(weth.balanceOf(user), userWethBalanceBefore - AMOUNT_IN, "WETH not transferred from user");
        assertEq(otherToken.balanceOf(user), userTokenBalanceBefore + expectedAmountOut, "Tokens not received by user");
    }

    /// @notice U:[FDEXG-6]: swapIn works for token to WETH
    function test_U_FDEXG_06_swapIn_works_for_token_to_weth() public {
        bool swap0to1 = false; // token to ETH/WETH

        // Approve gateway to spend other token
        vm.prank(user);
        otherToken.approve(address(gateway), AMOUNT_IN);

        uint256 userTokenBalanceBefore = otherToken.balanceOf(user);
        uint256 userWethBalanceBefore = weth.balanceOf(user);

        vm.prank(user);
        uint256 amountOut = gateway.swapIn(swap0to1, AMOUNT_IN, MIN_AMOUNT_OUT, user);

        uint256 expectedAmountOut = (AMOUNT_IN * 1e18) / EXCHANGE_RATE - 1;
        uint256 expectedTransferAmount = expectedAmountOut;

        assertEq(amountOut, expectedAmountOut, "Incorrect amount out returned");
        assertEq(otherToken.balanceOf(user), userTokenBalanceBefore - AMOUNT_IN, "Tokens not transferred from user");
        assertEq(weth.balanceOf(user), userWethBalanceBefore + expectedTransferAmount, "WETH not received by user");
        assertEq(weth.balanceOf(address(gateway)), 1, "Gateway should keep 1 wei for gas savings");
    }

    /// @notice U:[FDEXG-7]: swapIn works with ETH as token1
    function test_U_FDEXG_07_swapIn_works_with_eth_as_token1() public {
        // Create gateway with ETH as token1
        FluidDexPoolMock pool2 = new FluidDexPoolMock(address(otherToken), ETH, 456);
        pool2.setExchangeRate(EXCHANGE_RATE);
        vm.deal(address(pool2), 100 ether);
        otherToken.mint(address(pool2), 100 ether);

        FluidDexETHGateway gateway2 = new FluidDexETHGateway(address(pool2), address(weth));

        // Test swap from WETH to token (swap1to0)
        bool swap0to1 = false; // token1 to token0 (ETH/WETH to token)

        // Approve gateway to spend WETH
        vm.prank(user);
        weth.approve(address(gateway2), AMOUNT_IN);

        uint256 userWethBalanceBefore = weth.balanceOf(user);
        uint256 userTokenBalanceBefore = otherToken.balanceOf(user);

        vm.prank(user);
        uint256 amountOut = gateway2.swapIn(swap0to1, AMOUNT_IN, MIN_AMOUNT_OUT, user);

        uint256 expectedAmountOut = (AMOUNT_IN * 1e18) / EXCHANGE_RATE;
        assertEq(amountOut, expectedAmountOut, "Incorrect amount out");
        assertEq(weth.balanceOf(user), userWethBalanceBefore - AMOUNT_IN, "WETH not transferred from user");
        assertEq(otherToken.balanceOf(user), userTokenBalanceBefore + expectedAmountOut, "Tokens not received by user");
    }

    receive() external payable {}
}
