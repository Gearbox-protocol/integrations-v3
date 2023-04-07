// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {ZeroAddressException} from "@gearbox-protocol/core-v3/contracts/interfaces/IErrors.sol";
import {USDC_EXCHANGE_AMOUNT, FRIEND, USER} from "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

import {WrappedAToken} from "../../../adapters/aave/WrappedAToken.sol";
import {IAToken} from "../../../integrations/aave/IAToken.sol";

import {AaveTestHelper} from "./AaveTestHelper.sol";

/// @title Wrapped aToken test
/// @notice [WAT]: Unit tests for Wrapped aToken
contract WrappedATokenTest is AaveTestHelper {
    event Deposit(address indexed account, uint256 assets, uint256 shares);
    event Withdraw(address indexed account, uint256 assets, uint256 shares);

    WrappedAToken public waToken;

    function setUp() public {
        _setupAaveSuite(false);

        waToken = new WrappedAToken(IAToken(aUsdc));
        evm.label(address(waToken), "waUSDC");
    }

    /// @notice [WAT-1]: Constructor reverts on zero address
    function test_WAT_01_constructor_reverts_on_zero_address() public {
        evm.expectRevert(ZeroAddressException.selector);
        new WrappedAToken(IAToken(address(0)));
    }

    /// @notice [WAT-2]: Constructor sets correct values
    function test_WAT_02_constructor_sets_correct_values() public {
        assertEq(address(waToken.aToken()), aUsdc, "Incorrect aUSDC address");
        assertEq(address(waToken.underlying()), usdc, "Incorrect USDC address");
        assertEq(address(waToken.lendingPool()), address(lendingPool), "Incorrect lending pool address");
        assertEq(waToken.name(), "Wrapped Aave interest bearing USDC", "Incorrect name");
        assertEq(waToken.symbol(), "waUSDC", "Incorrect symbol");
        assertEq(waToken.decimals(), 6, "Incorrect decimals");
    }

    /// @notice [WAT-3]: `balanceOfUnderlying` works correctly
    /// @dev Fuzzing times before measuring balances
    /// @dev Small deviations in expected and actual balances are allowed due to rounding errors
    ///      Generally, dust size grows with time and number of operations on the wrapper
    ///      Nevertheless, the test shows that wrapper stays solvent and doesn't lose deposited funds
    function test_WAT_03_balanceOfUnderlying_works_correctly(uint256 timedelta1, uint256 timedelta2) public {
        evm.assume(timedelta1 < 5 * 365 days && timedelta2 < 5 * 365 days);
        uint256 balance1;
        uint256 balance2;

        // mint equivalent amounts of aTokens and waTokens to first user and wait for some time
        _mintAToken(USER);
        _mintWAToken(USER);
        evm.warp(block.timestamp + timedelta1);

        // balances must stay equivalent (up to some dust)
        balance1 = waToken.balanceOfUnderlying(USER);
        expectBalanceGe(aUsdc, USER, balance1, "user 1 after t1");
        expectBalanceLe(aUsdc, USER, balance1 + 1, "user 1 after t1");

        // also, wrapper's total balance of aToken must be equal to user's balances of underlying
        expectBalanceGe(aUsdc, address(waToken), balance1, "wrapper after t1");
        expectBalanceLe(aUsdc, address(waToken), balance1 + 1, "wrapper after t1");

        // now mint equivalent amounts of aTokens and  waTokens to second user and wait for more time
        _mintAToken(FRIEND);
        _mintWAToken(FRIEND);
        evm.warp(block.timestamp + timedelta2);

        // balances must stay equivalent for both users
        balance1 = waToken.balanceOfUnderlying(USER);
        expectBalanceGe(aUsdc, USER, balance1, "user 1 after t2");
        expectBalanceLe(aUsdc, USER, balance1 + 1, "user 1 after t2");

        balance2 = waToken.balanceOfUnderlying(FRIEND);
        expectBalanceGe(aUsdc, FRIEND, balance2, "user 2 after t2");
        expectBalanceLe(aUsdc, FRIEND, balance2 + 2, "user 2 after t2");

        // finally, wrapper's total balance of aToken must be equal to sum of users' balances of underlying
        expectBalanceGe(aUsdc, address(waToken), balance1 + balance2 - 1, "wrapper after t2");
        expectBalanceLe(aUsdc, address(waToken), balance1 + balance2 + 4, "wrapper after t2");
    }

    /// @notice [WAT-4]: `exchangeRate` can not be manipulated
    function test_WAT_04_exchangeRate_can_not_be_manipulated() public {
        uint256 exchangeRateBefore = waToken.exchangeRate();

        tokenTestSuite.mint(usdc, address(this), USDC_EXCHANGE_AMOUNT);
        tokenTestSuite.approve(usdc, address(this), address(lendingPool), USDC_EXCHANGE_AMOUNT);
        lendingPool.deposit(usdc, USDC_EXCHANGE_AMOUNT, address(waToken), 0);

        assertEq(waToken.exchangeRate(), exchangeRateBefore, "exchangeRate changed");
    }

    /// @notice [WAT-5]: `deposit` works correctly
    /// @dev Fuzzing time before deposit to see if wrapper handles interest properly
    /// @dev Final aUSDC balances are allowed to deviate by 1 from expected values due to rounding
    function test_WAT_05_deposit_works_correctly(uint256 timedelta) public {
        evm.assume(timedelta < 3 * 365 days);
        evm.warp(block.timestamp + timedelta);
        uint256 amount = _mintAToken(USER);

        uint256 assets = amount / 2;
        uint256 expectedShares = assets * WAD / waToken.exchangeRate();

        tokenTestSuite.approve(aUsdc, USER, address(waToken), assets);

        evm.expectEmit(true, false, false, true);
        emit Deposit(USER, assets, expectedShares);

        evm.prank(USER);
        uint256 shares = waToken.deposit(assets);

        assertEq(shares, expectedShares);

        expectBalanceGe(aUsdc, USER, amount - assets - 1, "");
        expectBalanceLe(aUsdc, USER, amount - assets + 1, "");
        expectBalance(address(waToken), USER, shares);

        assertEq(waToken.totalSupply(), shares);
        expectBalanceGe(aUsdc, address(waToken), assets - 1, "");
        expectBalanceLe(aUsdc, address(waToken), assets + 1, "");
    }

    /// @notice [WAT-6]: `depositUnderlying` works correctly
    /// @dev Fuzzing time before deposit to see if wrapper handles interest properly
    /// @dev Final aUSDC balances are allowed to deviate by 1 from expected values due to rounding
    function test_WAT_06_depositUnderlying_works_correctly(uint256 timedelta) public {
        evm.assume(timedelta < 3 * 365 days);
        evm.warp(block.timestamp + timedelta);
        uint256 amount = _mintUnderlying(USER);

        uint256 assets = amount / 2;
        uint256 expectedShares = assets * WAD / waToken.exchangeRate();

        tokenTestSuite.approve(usdc, USER, address(waToken), assets);

        evm.expectCall(address(lendingPool), abi.encodeCall(lendingPool.deposit, (usdc, assets, address(waToken), 0)));

        evm.expectEmit(true, false, false, true);
        emit Deposit(USER, assets, expectedShares);

        evm.prank(USER);
        uint256 shares = waToken.depositUnderlying(assets);

        assertEq(shares, expectedShares);

        expectBalance(usdc, USER, amount - assets);
        expectBalance(address(waToken), USER, shares);

        assertEq(waToken.totalSupply(), shares);
        expectBalance(usdc, address(waToken), 0);
        expectBalanceGe(aUsdc, address(waToken), assets - 1, "");
        expectBalanceLe(aUsdc, address(waToken), assets + 1, "");
    }

    /// @notice [WAT-7]: `withdraw` works correctly
    /// @dev Fuzzing time before deposit to see if wrapper handles interest properly
    /// @dev Final aUSDC balances are allowed to deviate by 1 from expected values due to rounding
    function test_WAT_07_withdraw_works_correctly(uint256 timedelta) public {
        evm.assume(timedelta < 3 * 365 days);
        uint256 amount = _mintWAToken(USER);
        evm.warp(block.timestamp + timedelta);

        uint256 shares = amount / 2;
        uint256 expectedAssets = shares * waToken.exchangeRate() / WAD;
        uint256 wrapperBalance = tokenTestSuite.balanceOf(aUsdc, address(waToken));

        evm.expectEmit(true, false, false, true);
        emit Withdraw(USER, expectedAssets, shares);

        evm.prank(USER);
        uint256 assets = waToken.withdraw(shares);

        assertEq(assets, expectedAssets);

        expectBalanceGe(aUsdc, USER, assets - 1, "");
        expectBalanceLe(aUsdc, USER, assets + 1, "");
        expectBalance(address(waToken), USER, amount - shares);

        assertEq(waToken.totalSupply(), amount - shares);
        expectBalanceGe(aUsdc, address(waToken), wrapperBalance - assets - 1, "");
        expectBalanceLe(aUsdc, address(waToken), wrapperBalance - assets + 1, "");
    }

    /// @notice [WAT-8]: `withdrawUnderlying` works correctly
    /// @dev Fuzzing time before deposit to see if wrapper handles interest properly
    /// @dev Final aUSDC balances are allowed to deviate by 1 from expected values due to rounding
    function test_WAT_08_withdrawUnderlying_works_correctly(uint256 timedelta) public {
        evm.assume(timedelta < 3 * 365 days);
        uint256 amount = _mintWAToken(USER);
        evm.warp(block.timestamp + timedelta);

        uint256 shares = amount / 2;
        uint256 expectedAssets = shares * waToken.exchangeRate() / WAD;
        uint256 wrapperBalance = tokenTestSuite.balanceOf(aUsdc, address(waToken));

        evm.expectEmit(true, false, false, true);
        emit Withdraw(USER, expectedAssets, shares);

        evm.expectCall(address(lendingPool), abi.encodeCall(lendingPool.withdraw, (usdc, expectedAssets, USER)));

        evm.prank(USER);
        uint256 assets = waToken.withdrawUnderlying(shares);

        assertEq(assets, expectedAssets);

        expectBalance(usdc, USER, assets);
        expectBalance(address(waToken), USER, amount - shares);

        assertEq(waToken.totalSupply(), amount - shares);
        expectBalance(usdc, address(waToken), 0);
        expectBalanceGe(aUsdc, address(waToken), wrapperBalance - assets - 1, "");
        expectBalanceLe(aUsdc, address(waToken), wrapperBalance - assets + 1, "");
    }

    /// @notice [WAT-9]: waToken resets lendingPool allowance if it falls too low
    function test_WAT_09_waToken_resets_lendingPool_allowance_if_it_falls_too_low() public {
        uint256 amount = _mintUnderlying(USER);
        tokenTestSuite.approve(usdc, USER, address(waToken), amount);

        // simulate the situation when lendingPool runs out of approval for USDC from waUSDC
        tokenTestSuite.approve(usdc, address(waToken), address(lendingPool), amount - 1);

        // waToken then should reset it back to max
        evm.expectCall(
            usdc, abi.encodeWithSignature("approve(address,uint256)", address(lendingPool), type(uint256).max)
        );

        evm.prank(USER);
        waToken.depositUnderlying(amount);
    }

    /// @dev Mints USDC to user
    function _mintUnderlying(address user) internal returns (uint256 amount) {
        amount = USDC_EXCHANGE_AMOUNT;
        tokenTestSuite.mint(usdc, user, amount);
    }

    /// @dev Mints aUSDC to user
    function _mintAToken(address user) internal returns (uint256 amount) {
        amount = _mintUnderlying(user);
        tokenTestSuite.approve(usdc, user, address(lendingPool), amount);
        evm.prank(user);
        lendingPool.deposit(usdc, amount, address(user), 0);
    }

    /// @dev Mints waUSDC to user
    function _mintWAToken(address user) internal returns (uint256 amount) {
        uint256 assets = _mintUnderlying(user);
        tokenTestSuite.approve(usdc, user, address(waToken), assets);
        evm.prank(user);
        amount = waToken.depositUnderlying(assets);
    }
}
