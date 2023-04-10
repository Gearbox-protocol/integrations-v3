// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {IWETH} from "@gearbox-protocol/core-v2/contracts/interfaces/external/IWETH.sol";
import {ZeroAddressException} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";
import {USER} from "@gearbox-protocol/core-v2/contracts/test/lib/constants.sol";

import {CEtherGateway} from "../../../adapters/compound/CEtherGateway.sol";
import {ICompoundV2_Exceptions} from "../../../interfaces/compound/ICompoundV2_CTokenAdapter.sol";

import {Tokens} from "../../config/Tokens.sol";
import {TokensTestSuite} from "../../suites/TokensTestSuite.sol";
import {CEtherMock, REDEEM_ERROR, REDEEM_UNDERLYING_ERROR} from "../../mocks/integrations/compound/CEtherMock.sol";

/// @title CEther gateway test
/// @notice [CEG]: Unit tests for CEther gateway
contract CEtherGatewayTest is Test, ICompoundV2_Exceptions {
    using Address for address payable;

    IWETH weth;
    CEtherMock ceth;
    CEtherGateway gateway;

    TokensTestSuite tokensTestSuite;
    uint256 constant WETH_AMOUNT = 10 * WAD;

    function setUp() public {
        tokensTestSuite = new TokensTestSuite();

        weth = IWETH(tokensTestSuite.addressOf(Tokens.WETH));

        // initial exchange rate 0.02 cETH per ETH, 5% yearly interest
        ceth = new CEtherMock(0.02 ether, 0.05 ether);
        vm.deal(address(ceth), 100 * WAD);
        skip(365 days);

        gateway = new CEtherGateway(address(weth), address(ceth));

        vm.label(address(weth), "WETH");
        vm.label(address(ceth), "cETH");
        vm.label(address(gateway), "cETH_GATEWAY");
        vm.label(USER, "USER");
    }

    /// @notice [CEG-1]: Constructor reverts on zero address
    function test_CEG_01_constructor_reverts_on_zero_address() public {
        vm.expectRevert(ZeroAddressException.selector);
        new CEtherGateway(address(0), address(ceth));

        vm.expectRevert(ZeroAddressException.selector);
        new CEtherGateway(address(weth), address(0));
    }

    /// @notice [CEG-2]: Constructor sets correct values
    function test_CEG_02_constructor_sets_correct_values() public {
        assertEq(address(gateway.weth()), address(weth), "Incorrect WETH address");
        assertEq(address(gateway.ceth()), address(ceth), "Incorrect cETH address");
    }

    /// @notice [CEG-3]: Gateway can receive ETH
    function test_CEG_03_gateway_can_receive_eth() public {
        assertEq(address(gateway).balance, 0);
        payable(gateway).sendValue(1 ether);
        assertEq(address(gateway).balance, 1 ether);
    }

    /// @notice [CEG-4]: `mint` works correctly
    function test_CEG_04_mint_works_correctly() public {
        uint256 mintAmount = 10 * WAD;
        tokensTestSuite.mint(Tokens.WETH, USER, mintAmount);
        tokensTestSuite.approve(Tokens.WETH, USER, address(gateway), mintAmount);

        uint256 cethBalanceExpected = mintAmount * WAD / ceth.exchangeRateCurrent();

        vm.expectCall(address(weth), abi.encodeCall(IWETH.withdraw, (mintAmount)));
        vm.expectCall(address(ceth), mintAmount, abi.encodeCall(CEtherMock.mint, ()));

        vm.prank(USER);
        uint256 error = gateway.mint(mintAmount);

        assertEq(error, 0, "Non-zero error code");
        assertEq(tokensTestSuite.balanceOf(address(weth), USER), 0, "Incorrect WETH balance");
        assertEq(tokensTestSuite.balanceOf(address(ceth), USER), cethBalanceExpected, "Incorrect cETH balance");
    }

    /// @notice [CEG-5]: `redeem` works correctly
    function test_CEG_05_redeem_works_correctly() public {
        uint256 cethBalance = _mintCEther(10 * WAD);

        uint256 redeemTokens = cethBalance / 2;
        tokensTestSuite.approve(address(ceth), USER, address(gateway), redeemTokens);

        uint256 redeemAmountExpected = redeemTokens * ceth.exchangeRateCurrent() / WAD;

        vm.expectCall(address(ceth), abi.encodeCall(CEtherMock.redeem, (redeemTokens)));
        vm.expectCall(address(weth), redeemAmountExpected, abi.encodeCall(IWETH.deposit, ()));

        vm.prank(USER);
        uint256 error = gateway.redeem(redeemTokens);

        assertEq(error, 0, "Non-zero error code");
        assertEq(tokensTestSuite.balanceOf(address(weth), USER), redeemAmountExpected, "Incorrect WETH balance");
        assertEq(tokensTestSuite.balanceOf(address(ceth), USER), cethBalance - redeemTokens, "Incorrect cETH balance");
    }

    /// @notice [CEG-6]: `redeem` reverts on non-zero CEther error code
    function test_CEG_06_redeem_reverts_on_non_zero_error_code() public {
        _mintCEther(10 * WAD);

        uint256 redeemTokens = 1;
        tokensTestSuite.approve(address(ceth), USER, address(gateway), redeemTokens);

        ceth.setFailing(true);

        vm.expectRevert(abi.encodeWithSelector(CTokenError.selector, REDEEM_ERROR));
        vm.prank(USER);
        gateway.redeem(redeemTokens);
    }

    /// @notice [CEG-7]: `redeemUnderlying` works correctly
    function test_CEG_07_redeemUnderlying_works_correctly() public {
        uint256 cethBalance = _mintCEther(10 * WAD);

        uint256 redeemAmount = 5 * WAD;
        tokensTestSuite.approve(address(ceth), USER, address(gateway), cethBalance);

        uint256 redeemTokensExpected = redeemAmount * WAD / ceth.exchangeRateCurrent();

        vm.expectCall(address(ceth), abi.encodeCall(CEtherMock.redeemUnderlying, (redeemAmount)));
        vm.expectCall(address(weth), redeemAmount, abi.encodeCall(IWETH.deposit, ()));

        vm.prank(USER);
        uint256 error = gateway.redeemUnderlying(redeemAmount);

        assertEq(error, 0, "Non-zero error code");
        assertEq(tokensTestSuite.balanceOf(address(weth), USER), redeemAmount, "Incorrect WETH balance");
        assertEq(
            tokensTestSuite.balanceOf(address(ceth), USER), cethBalance - redeemTokensExpected, "Incorrect cETH balance"
        );
    }

    /// @notice [CEG-8]: `redeemUnderlying` reverts on non-zero CEther error code
    function test_CEG_08_redeemUnderlying_reverts_on_non_zero_error_code() public {
        uint256 cethBalance = _mintCEther(10 * WAD);

        uint256 redeemAmount = 1;
        tokensTestSuite.approve(address(ceth), USER, address(gateway), cethBalance);

        ceth.setFailing(true);

        vm.expectRevert(abi.encodeWithSelector(CTokenError.selector, REDEEM_UNDERLYING_ERROR));
        vm.prank(USER);
        gateway.redeemUnderlying(redeemAmount);
    }

    /// @dev Deposits given amount of WETH to cETH through gateway for user
    function _mintCEther(uint256 mintAmount) internal returns (uint256 cethBalance) {
        tokensTestSuite.mint(Tokens.WETH, USER, mintAmount);
        tokensTestSuite.approve(Tokens.WETH, USER, address(gateway), mintAmount);
        vm.prank(USER);
        gateway.mint(WETH_AMOUNT);

        cethBalance = tokensTestSuite.balanceOf(address(ceth), USER);
        skip(365 days);
    }
}
