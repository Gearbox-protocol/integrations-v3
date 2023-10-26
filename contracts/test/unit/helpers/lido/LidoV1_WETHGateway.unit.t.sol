// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IWETH} from "@gearbox-protocol/core-v2/contracts/interfaces/external/IWETH.sol";
import {
    ReceiveIsNotAllowedException,
    ZeroAddressException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";

import {LidoV1Gateway} from "../../../../helpers/lido/LidoV1_WETHGateway.sol";
import {IstETH} from "../../../../integrations/lido/IstETH.sol";

/// @title Lido v1 gateway unit test
/// @notice U:[LWG]: Unit tests for Lido v1 WETH gateway
contract LidoV1GatewayUnitTest is Test {
    using Address for address payable;

    LidoV1Gateway gateway;

    TokensTestSuite tokensTestSuite;
    address weth;
    address stETH;

    address user = makeAddr("USER");
    uint256 wethAmountIn = 1 ether;
    uint256 stETHAmountOut = 0.8 ether;
    address referral = makeAddr("REFERRAL");

    function setUp() public {
        tokensTestSuite = new TokensTestSuite();

        weth = tokensTestSuite.wethToken();
        deal(weth, 100 ether);

        stETH = address(new ERC20Mock("staked ETH", "stETH", 18));
        vm.mockCall(stETH, wethAmountIn, abi.encodeCall(IstETH.submit, (referral)), abi.encode(stETHAmountOut));

        gateway = new LidoV1Gateway(weth, stETH);
    }

    /// @notice U:[LWG-1]: Constructor works as expected
    function test_U_LWG_01_constructor_works_as_expected() public {
        vm.expectRevert(ZeroAddressException.selector);
        new LidoV1Gateway(address(0), stETH);

        vm.expectRevert(ZeroAddressException.selector);
        new LidoV1Gateway(weth, address(0));

        assertEq(gateway.weth(), weth, "Incorrect weth");
        assertEq(gateway.stETH(), stETH, "Incorrect stETH");
    }

    /// @notice U:[LWG-2]: `receive` works as expected
    function test_U_LWG_02_receive_works_as_expected() public {
        vm.expectRevert(ReceiveIsNotAllowedException.selector);
        payable(gateway).sendValue(1 ether);

        deal(weth, 1 ether);
        vm.prank(weth);
        payable(gateway).sendValue(1 ether);

        assertEq(address(gateway).balance, 1 ether);
    }

    /// @notice U:[LWG-3]: `submit` works as expected
    function test_U_LWG_03_submit_works_as_expected() public {
        deal({token: weth, to: user, give: wethAmountIn});
        deal({token: stETH, to: address(gateway), give: stETHAmountOut});
        tokensTestSuite.approve(weth, user, address(gateway), wethAmountIn);

        vm.expectCall(weth, abi.encodeCall(IWETH.withdraw, (wethAmountIn)));
        vm.expectCall(stETH, wethAmountIn, abi.encodeCall(IstETH.submit, (referral)));

        vm.prank(user);
        uint256 value = gateway.submit(wethAmountIn, referral);
        assertEq(value, stETHAmountOut, "Incorrect stETH amount");
        assertEq(tokensTestSuite.balanceOf(weth, user), 0, "Incorrect WETH balance");
        assertEq(tokensTestSuite.balanceOf(stETH, user), stETHAmountOut, "Incorrect stETH balance");
    }
}
