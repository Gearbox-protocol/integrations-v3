// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IWETH} from "@gearbox-protocol/core-v2/contracts/interfaces/external/IWETH.sol";
import {ZeroAddressException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {TokensTestSuite, Tokens} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";

import {CEtherGateway} from "../../../../helpers/compound/CompoundV2_CEtherGateway.sol";
import {ICompoundV2_Exceptions} from "../../../../interfaces/compound/ICompoundV2_CTokenAdapter.sol";

import {CEtherMock, REDEEM_ERROR, REDEEM_UNDERLYING_ERROR} from "../../../mocks/integrations/compound/CEtherMock.sol";

/// @title CEther gateway unit test
/// @notice U:[CEG]: Unit tests for Compound v2 CEther gateway
contract CEtherGatewayUnitTest is Test, ICompoundV2_Exceptions {
    using Address for address payable;

    IWETH weth;
    CEtherMock ceth;
    CEtherGateway gateway;

    address user;

    TokensTestSuite tokensTestSuite;
    uint256 constant WETH_AMOUNT = 10 ether;

    function setUp() public {
        tokensTestSuite = new TokensTestSuite();

        weth = IWETH(tokensTestSuite.addressOf(Tokens.WETH));

        // initial exchange rate 0.02 cETH per ETH, 5% yearly interest
        ceth = new CEtherMock(0.02 ether, 0.05 ether);
        vm.deal(address(ceth), 100 ether);
        skip(365 days);

        gateway = new CEtherGateway(address(weth), address(ceth));

        vm.label(address(weth), "WETH");
        vm.label(address(ceth), "cETH");
        vm.label(address(gateway), "cETH_GATEWAY");

        user = makeAddr("user");
    }

    /// @notice U:[CEG-1]: Constructor works as expected
    function test_U_CEG_01_constructor_works_as_expected() public {
        vm.expectRevert(ZeroAddressException.selector);
        new CEtherGateway(address(0), address(ceth));

        vm.expectRevert(ZeroAddressException.selector);
        new CEtherGateway(address(weth), address(0));

        assertEq(gateway.weth(), address(weth), "Incorrect WETH address");
        assertEq(gateway.ceth(), address(ceth), "Incorrect cETH address");
    }

    /// @notice U:[CEG-2]: Gateway can receive ETH
    function test_U_CEG_02_gateway_can_receive_eth() public {
        assertEq(address(gateway).balance, 0);
        payable(gateway).sendValue(1 ether);
        assertEq(address(gateway).balance, 1 ether);
    }

    /// @notice U:[CEG-3]: `mint` works as expected
    function test_U_CEG_03_mint_works_as_expected() public {
        uint256 mintAmount = 10 ether;
        tokensTestSuite.mint(Tokens.WETH, user, mintAmount);
        tokensTestSuite.approve(Tokens.WETH, user, address(gateway), mintAmount);

        uint256 cethBalanceExpected = mintAmount * 1 ether / ceth.exchangeRateCurrent();

        vm.expectCall(address(weth), abi.encodeCall(IWETH.withdraw, (mintAmount)));
        vm.expectCall(address(ceth), mintAmount, abi.encodeCall(CEtherMock.mint, ()));

        vm.prank(user);
        uint256 error = gateway.mint(mintAmount);

        assertEq(error, 0, "Non-zero error code");
        assertEq(tokensTestSuite.balanceOf(address(weth), user), 0, "Incorrect WETH balance");
        assertEq(tokensTestSuite.balanceOf(address(ceth), user), cethBalanceExpected, "Incorrect cETH balance");
    }

    /// @notice U:[CEG-4]: `redeem` works as expected
    function test_U_CEG_04_redeem_works_as_expected() public {
        uint256 cethBalance = _mintCEther(10 ether);

        uint256 redeemTokens = cethBalance / 2;
        tokensTestSuite.approve(address(ceth), user, address(gateway), redeemTokens);

        uint256 redeemAmountExpected = redeemTokens * ceth.exchangeRateCurrent() / 1 ether;

        vm.expectCall(address(ceth), abi.encodeCall(CEtherMock.redeem, (redeemTokens)));
        vm.expectCall(address(weth), redeemAmountExpected, abi.encodeCall(IWETH.deposit, ()));

        vm.prank(user);
        uint256 error = gateway.redeem(redeemTokens);

        assertEq(error, 0, "Non-zero error code");
        assertEq(tokensTestSuite.balanceOf(address(weth), user), redeemAmountExpected, "Incorrect WETH balance");
        assertEq(tokensTestSuite.balanceOf(address(ceth), user), cethBalance - redeemTokens, "Incorrect cETH balance");
    }

    /// @notice U:[CEG-5]: `redeemUnderlying` works as expected
    function test_U_CEG_05_redeemUnderlying_works_as_expected() public {
        uint256 cethBalance = _mintCEther(10 ether);

        uint256 redeemAmount = 5 ether;
        tokensTestSuite.approve(address(ceth), user, address(gateway), cethBalance);

        uint256 redeemTokensExpected = redeemAmount * 1 ether / ceth.exchangeRateCurrent();

        vm.expectCall(address(ceth), abi.encodeCall(CEtherMock.redeemUnderlying, (redeemAmount)));
        vm.expectCall(address(weth), redeemAmount, abi.encodeCall(IWETH.deposit, ()));

        vm.prank(user);
        uint256 error = gateway.redeemUnderlying(redeemAmount);

        assertEq(error, 0, "Non-zero error code");
        assertEq(tokensTestSuite.balanceOf(address(weth), user), redeemAmount, "Incorrect WETH balance");
        assertEq(
            tokensTestSuite.balanceOf(address(ceth), user), cethBalance - redeemTokensExpected, "Incorrect cETH balance"
        );
    }

    /// @notice U:[CEG-6]: redeem functions revert on non-zero CEther error code
    function test_U_CEG_06_redeem_functions_revert_on_non_zero_error_code() public {
        uint256 cethBalance = _mintCEther(10 ether);
        tokensTestSuite.approve(address(ceth), user, address(gateway), cethBalance);

        ceth.setFailing(true);

        vm.expectRevert(abi.encodeWithSelector(CTokenError.selector, REDEEM_ERROR));
        vm.prank(user);
        gateway.redeem(1 ether);

        vm.expectRevert(abi.encodeWithSelector(CTokenError.selector, REDEEM_UNDERLYING_ERROR));
        vm.prank(user);
        gateway.redeemUnderlying(1 ether);
    }

    /// @dev Deposits given amount of WETH to cETH through gateway for user
    function _mintCEther(uint256 mintAmount) internal returns (uint256 cethBalance) {
        tokensTestSuite.mint(Tokens.WETH, user, mintAmount);
        tokensTestSuite.approve(Tokens.WETH, user, address(gateway), mintAmount);
        vm.prank(user);
        gateway.mint(WETH_AMOUNT);

        cethBalance = tokensTestSuite.balanceOf(address(ceth), user);
        skip(365 days);
    }
}
