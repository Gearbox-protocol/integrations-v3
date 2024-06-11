// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {ZeroAddressException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {IWrappedATokenEvents, WrappedAToken} from "../../../../helpers/aave/AaveV2_WrappedAToken.sol";

import {LendingPoolMock} from "../../../mocks/integrations/aave/LendingPoolMock.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {FRIEND, USER} from "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";
import {BalanceHelper} from "@gearbox-protocol/core-v3/contracts/test/helpers/BalanceHelper.sol";
import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";

/// @title Wrapped aToken unit test
/// @notice U:[WAT]: Unit tests for Wrapped aToken
contract WrappedATokenUnitTest is Test, BalanceHelper, IWrappedATokenEvents {
    WrappedAToken public waToken;

    LendingPoolMock lendingPool;
    address token;
    address aToken;

    uint256 constant TOKEN_AMOUNT = 1e10;

    function setUp() public {
        tokenTestSuite = new TokensTestSuite();
        lendingPool = new LendingPoolMock();

        token = address(new ERC20Mock("Test Token", "TEST", 6));
        aToken = lendingPool.addReserve(token, 0.02e27); // 2%
        deal(token, aToken, 1e12); // add some liquidity
        waToken = new WrappedAToken(aToken);

        vm.label(token, "TOKEN");
        vm.label(aToken, "aTOKEN");
        vm.label(address(waToken), "waTOKEN");
        vm.label(address(lendingPool), "LENDING_POOL");

        vm.warp(block.timestamp + 365 days);
    }

    /// @notice U:[WAT-1]: Constructor reverts on zero address
    function test_U_WAT_01_constructor_reverts_on_zero_address() public {
        vm.expectRevert(ZeroAddressException.selector);
        new WrappedAToken(address(0));
    }

    /// @notice U:[WAT-2]: Constructor sets correct values
    function test_U_WAT_02_constructor_sets_correct_values() public {
        assertEq(waToken.aToken(), aToken, "Incorrect aUSDC address");
        assertEq(waToken.underlying(), token, "Incorrect USDC address");
        assertEq(waToken.lendingPool(), address(lendingPool), "Incorrect lending pool address");
        assertEq(waToken.name(), "Wrapped Aave interest bearing Test Token", "Incorrect name");
        assertEq(waToken.symbol(), "waTEST", "Incorrect symbol");
        assertEq(waToken.decimals(), 6, "Incorrect decimals");
        assertEq(
            ERC20Mock(token).allowance(address(waToken), address(lendingPool)), type(uint256).max, "Incorrect allowance"
        );
    }

    /// @notice U:[WAT-3]: `balanceOfUnderlying` works correctly
    /// @dev Fuzzing times before measuring balances
    /// @dev Small deviations in expected and actual balances are allowed due to rounding errors
    ///      Generally, dust size grows with time and number of operations on the wrapper
    ///      Nevertheless, the test shows that wrapper stays solvent and doesn't lose deposited funds
    function test_U_WAT_03_balanceOfUnderlying_works_correctly(uint256 timedelta1, uint256 timedelta2) public {
        vm.assume(timedelta1 < 5 * 365 days && timedelta2 < 5 * 365 days);
        uint256 balance1;
        uint256 balance2;

        // mint equivalent amounts of aTokens and waTokens to first user and wait for some time
        _mintAToken(USER);
        _mintWAToken(USER);
        vm.warp(block.timestamp + timedelta1);

        // balances must stay equivalent (up to some dust)
        balance1 = waToken.balanceOfUnderlying(USER);
        expectBalanceGe(aToken, USER, balance1, "user 1 after t1");
        expectBalanceLe(aToken, USER, balance1 + 2, "user 1 after t1");

        // also, wrapper's total balance of aToken must be equal to user's balances of underlying
        expectBalanceGe(aToken, address(waToken), balance1, "wrapper after t1");
        expectBalanceLe(aToken, address(waToken), balance1 + 2, "wrapper after t1");

        // now mint equivalent amounts of aTokens and  waTokens to second user and wait for more time
        _mintAToken(FRIEND);
        _mintWAToken(FRIEND);
        vm.warp(block.timestamp + timedelta2);

        // balances must stay equivalent for both users
        balance1 = waToken.balanceOfUnderlying(USER);
        expectBalanceGe(aToken, USER, balance1, "user 1 after t2");
        expectBalanceLe(aToken, USER, balance1 + 2, "user 1 after t2");

        balance2 = waToken.balanceOfUnderlying(FRIEND);
        expectBalanceGe(aToken, FRIEND, balance2, "user 2 after t2");
        expectBalanceLe(aToken, FRIEND, balance2 + 2, "user 2 after t2");

        // finally, wrapper's total balance of aToken must be equal to sum of users' balances of underlying
        expectBalanceGe(aToken, address(waToken), balance1 + balance2 - 1, "wrapper after t2");
        expectBalanceLe(aToken, address(waToken), balance1 + balance2 + 4, "wrapper after t2");
    }

    /// @notice U:[WAT-4]: `exchangeRate` can not be manipulated
    function test_U_WAT_04_exchangeRate_can_not_be_manipulated() public {
        uint256 exchangeRateBefore = waToken.exchangeRate();

        deal(token, address(this), TOKEN_AMOUNT);
        tokenTestSuite.approve(token, address(this), address(lendingPool), TOKEN_AMOUNT);
        lendingPool.deposit(token, TOKEN_AMOUNT, address(waToken), 0);

        assertEq(waToken.exchangeRate(), exchangeRateBefore, "exchangeRate changed");
    }

    /// @notice U:[WAT-5]: `deposit` works correctly
    /// @dev Fuzzing time before deposit to see if wrapper handles interest properly
    /// @dev Final aToken balances are allowed to deviate by 1 from expected values due to rounding
    function test_U_WAT_05_deposit_works_correctly(uint256 timedelta) public {
        vm.assume(timedelta < 3 * 365 days);
        vm.warp(block.timestamp + timedelta);
        uint256 amount = _mintAToken(USER);

        uint256 assets = amount / 2;
        uint256 expectedShares = assets * WAD / waToken.exchangeRate();

        tokenTestSuite.approve(aToken, USER, address(waToken), assets);

        vm.expectEmit(true, false, false, true);
        emit Deposit(USER, assets, expectedShares);

        vm.prank(USER);
        uint256 shares = waToken.deposit(assets);

        assertEq(shares, expectedShares);

        expectBalanceGe(aToken, USER, amount - assets - 1, "");
        expectBalanceLe(aToken, USER, amount - assets + 1, "");
        expectBalance(address(waToken), USER, shares);

        assertEq(waToken.totalSupply(), shares);
        expectBalanceGe(aToken, address(waToken), assets - 1, "");
        expectBalanceLe(aToken, address(waToken), assets + 1, "");
    }

    /// @notice U:[WAT-6]: `depositUnderlying` works correctly
    /// @dev Fuzzing time before deposit to see if wrapper handles interest properly
    /// @dev Final aToken balances are allowed to deviate by 1 from expected values due to rounding
    function test_U_WAT_06_depositUnderlying_works_correctly(uint256 timedelta) public {
        vm.assume(timedelta < 3 * 365 days);
        vm.warp(block.timestamp + timedelta);
        uint256 amount = _mintUnderlying(USER);

        uint256 assets = amount / 2;
        uint256 expectedShares = assets * WAD / waToken.exchangeRate();

        tokenTestSuite.approve(token, USER, address(waToken), assets);

        vm.expectCall(address(lendingPool), abi.encodeCall(lendingPool.deposit, (token, assets, address(waToken), 0)));

        vm.expectEmit(true, false, false, true);
        emit Deposit(USER, assets, expectedShares);

        vm.prank(USER);
        uint256 shares = waToken.depositUnderlying(assets);

        assertEq(shares, expectedShares);

        expectBalance(token, USER, amount - assets);
        expectBalance(address(waToken), USER, shares);

        assertEq(waToken.totalSupply(), shares);
        expectBalance(token, address(waToken), 0);
        expectBalanceGe(aToken, address(waToken), assets - 1, "");
        expectBalanceLe(aToken, address(waToken), assets + 1, "");
        assertEq(
            ERC20Mock(token).allowance(address(waToken), address(lendingPool)), type(uint256).max, "Incorrect allowance"
        );
    }

    /// @notice U:[WAT-7]: `withdraw` works correctly
    /// @dev Fuzzing time before deposit to see if wrapper handles interest properly
    /// @dev Final aToken balances are allowed to deviate by 1 from expected values due to rounding
    function test_U_WAT_07_withdraw_works_correctly(uint256 timedelta) public {
        vm.assume(timedelta < 3 * 365 days);
        uint256 amount = _mintWAToken(USER);
        vm.warp(block.timestamp + timedelta);

        uint256 shares = amount / 2;
        uint256 expectedAssets = shares * waToken.exchangeRate() / WAD;
        uint256 wrapperBalance = tokenTestSuite.balanceOf(aToken, address(waToken));

        vm.expectEmit(true, false, false, true);
        emit Withdraw(USER, expectedAssets, shares);

        vm.prank(USER);
        uint256 assets = waToken.withdraw(shares);

        assertEq(assets, expectedAssets);

        expectBalanceGe(aToken, USER, assets - 1, "");
        expectBalanceLe(aToken, USER, assets + 1, "");
        expectBalance(address(waToken), USER, amount - shares);

        assertEq(waToken.totalSupply(), amount - shares);
        expectBalanceGe(aToken, address(waToken), wrapperBalance - assets - 1, "");
        expectBalanceLe(aToken, address(waToken), wrapperBalance - assets + 1, "");
    }

    /// @notice U:[WAT-8]: `withdrawUnderlying` works correctly
    /// @dev Fuzzing time before deposit to see if wrapper handles interest properly
    /// @dev Final aToken balances are allowed to deviate by 1 from expected values due to rounding
    function test_U_WAT_08_withdrawUnderlying_works_correctly(uint256 timedelta) public {
        vm.assume(timedelta < 3 * 365 days);
        uint256 amount = _mintWAToken(USER);
        vm.warp(block.timestamp + timedelta);

        uint256 shares = amount / 2;
        uint256 expectedAssets = shares * waToken.exchangeRate() / WAD;
        uint256 wrapperBalance = tokenTestSuite.balanceOf(aToken, address(waToken));

        vm.expectEmit(true, false, false, true);
        emit Withdraw(USER, expectedAssets, shares);

        vm.expectCall(address(lendingPool), abi.encodeCall(lendingPool.withdraw, (token, expectedAssets, USER)));

        vm.prank(USER);
        uint256 assets = waToken.withdrawUnderlying(shares);

        assertEq(assets, expectedAssets);

        expectBalance(token, USER, assets);
        expectBalance(address(waToken), USER, amount - shares);

        assertEq(waToken.totalSupply(), amount - shares);
        expectBalance(token, address(waToken), 0);
        expectBalanceGe(aToken, address(waToken), wrapperBalance - assets - 1, "");
        expectBalanceLe(aToken, address(waToken), wrapperBalance - assets + 1, "");
    }

    /// @dev Mints token to user
    function _mintUnderlying(address user) internal returns (uint256 amount) {
        amount = TOKEN_AMOUNT;
        deal(token, user, amount);
    }

    /// @dev Mints aToken to user
    function _mintAToken(address user) internal returns (uint256 amount) {
        amount = _mintUnderlying(user);
        tokenTestSuite.approve(token, user, address(lendingPool), amount);
        vm.prank(user);
        lendingPool.deposit(token, amount, address(user), 0);
    }

    /// @dev Mints waToken to user
    function _mintWAToken(address user) internal returns (uint256 amount) {
        uint256 assets = _mintUnderlying(user);
        tokenTestSuite.approve(token, user, address(waToken), assets);
        vm.prank(user);
        amount = waToken.depositUnderlying(assets);
    }
}
