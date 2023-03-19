// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "../../interfaces/IAdapter.sol";

import {IWrappedAToken} from "../../interfaces/aave/IWrappedAToken.sol";
import {IAaveV2_WrappedATokenAdapter} from "../../interfaces/aave/IAaveV2_WrappedATokenAdapter.sol";

/// @title Aave V2 Wrapped aToken adapter
/// @notice Implements logic allowing CAs to convert between waTokens, aTokens and underlying tokens
contract AaveV2_WrappedATokenAdapter is AbstractAdapter, IAaveV2_WrappedATokenAdapter {
    /// @inheritdoc IAaveV2_WrappedATokenAdapter
    address public immutable override aToken;

    /// @inheritdoc IAaveV2_WrappedATokenAdapter
    address public immutable override underlying;

    /// @inheritdoc IAaveV2_WrappedATokenAdapter
    uint256 public immutable override waTokenMask;

    /// @inheritdoc IAaveV2_WrappedATokenAdapter
    uint256 public immutable override aTokenMask;

    /// @inheritdoc IAaveV2_WrappedATokenAdapter
    uint256 public immutable override tokenMask;

    AdapterType public constant override _gearboxAdapterType = AdapterType.AAVE_V2_WRAPPED_ATOKEN;
    uint16 public constant override _gearboxAdapterVersion = 1;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _waToken Wrapped aToken address
    constructor(address _creditManager, address _waToken) AbstractAdapter(_creditManager, _waToken) {
        waTokenMask = _getMaskOrRevert(targetContract);

        aToken = address(IWrappedAToken(targetContract).aToken());
        aTokenMask = _getMaskOrRevert(aToken);

        underlying = address(IWrappedAToken(targetContract).underlying());
        tokenMask = _getMaskOrRevert(underlying);
    }

    /// -------- ///
    /// DEPOSITS ///
    /// -------- ///

    /// @inheritdoc IAaveV2_WrappedATokenAdapter
    function deposit(uint256 assets) external override creditFacadeOnly {
        _deposit(assets, false);
    }

    /// @inheritdoc IAaveV2_WrappedATokenAdapter
    function depositAll() external override creditFacadeOnly {
        _depositAll(false);
    }

    /// @inheritdoc IAaveV2_WrappedATokenAdapter
    function depositUnderlying(uint256 assets) external override creditFacadeOnly {
        _deposit(assets, true);
    }

    /// @inheritdoc IAaveV2_WrappedATokenAdapter
    function depositAllUnderlying() external override creditFacadeOnly {
        _depositAll(true);
    }

    /// @dev Internal implementation of `deposit` and `depositUnderlying`
    ///      - underlying / aAoken is approved because waToken contract needs permission to transfer it
    ///      - waToken is enabled after the call
    ///      - underlying / aToken is not disabled after the call because operation doesn't spend the entire balance
    function _deposit(uint256 assets, bool fromUnderlying) internal {
        address tokenIn = fromUnderlying ? underlying : aToken;

        _approveToken(tokenIn, type(uint256).max);
        _execute(_encodeDeposit(assets, fromUnderlying));
        _approveToken(tokenIn, 1);
        _changeEnabledTokens(waTokenMask, 0);
    }

    /// @dev Internal implementation of `deposit` and `depositUnderlying`
    ///      - underlying / aAoken is approved because wrapped aToken contract needs permission to transfer it
    ///      - waToken is enabled after the call
    ///      - underlying / aToken is disabled after the call because operation spends the entire balance
    function _depositAll(bool fromUnderlying) internal {
        address creditAccount = _creditAccount();
        address tokenIn = fromUnderlying ? underlying : aToken;

        uint256 balance = IERC20(tokenIn).balanceOf(creditAccount);
        if (balance <= 1) return;

        uint256 assets;
        unchecked {
            assets = balance - 1;
        }

        _approveToken(tokenIn, type(uint256).max);
        _execute(_encodeDeposit(assets, fromUnderlying));
        _approveToken(tokenIn, 1);
        _changeEnabledTokens(waTokenMask, fromUnderlying ? tokenMask : aTokenMask);
    }

    /// @dev Returns data for `IWrappedAToken`'s `deposit` or `depositUnderlying` call
    function _encodeDeposit(uint256 assets, bool fromUnderlying) internal pure returns (bytes memory callData) {
        callData = fromUnderlying
            ? abi.encodeCall(IWrappedAToken.depositUnderlying, (assets))
            : abi.encodeCall(IWrappedAToken.deposit, (assets));
    }

    /// ----------- ///
    /// WITHDRAWALS ///
    /// ----------- ///

    /// @inheritdoc IAaveV2_WrappedATokenAdapter
    function withdraw(uint256 shares) external override creditFacadeOnly {
        _withdraw(shares, false);
    }

    /// @inheritdoc IAaveV2_WrappedATokenAdapter
    function withdrawAll() external override creditFacadeOnly {
        _withdrawAll(false);
    }

    /// @inheritdoc IAaveV2_WrappedATokenAdapter
    function withdrawUnderlying(uint256 shares) external override creditFacadeOnly {
        _withdraw(shares, true);
    }

    /// @inheritdoc IAaveV2_WrappedATokenAdapter
    function withdrawAllUnderlying() external override creditFacadeOnly {
        _withdrawAll(true);
    }

    /// @dev Internal implementation of `withdraw` and `withdrawUnderlying`
    ///      - waToken is not approved because it doesn't need permission to burn share tokens
    ///      - underlying / aToken is enabled after the call
    ///      - waToken is not disabled after the call because operation doesn't spend the entire balance
    function _withdraw(uint256 shares, bool toUnderlying) internal {
        _execute(_encodeWithdraw(shares, toUnderlying));
        _changeEnabledTokens(toUnderlying ? tokenMask : aTokenMask, 0);
    }

    /// @dev Internal implementation of `withdraw` and `withdrawUnderlying`
    ///      - waToken is not approved because it doesn't need permission to burn share tokens
    ///      - underlying / aToken is enabled after the call
    ///      - waToken is disabled after the call because operation spends the entire balance
    function _withdrawAll(bool toUnderlying) internal {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(targetContract).balanceOf(creditAccount);
        if (balance <= 1) return;

        uint256 shares;
        unchecked {
            shares = balance - 1;
        }

        _execute(_encodeWithdraw(shares, toUnderlying));
        _changeEnabledTokens(toUnderlying ? tokenMask : aTokenMask, waTokenMask);
    }

    /// @dev Returns data for `IWrappedAToken`'s `withdraw` or `withdrawUnderlying` call
    function _encodeWithdraw(uint256 shares, bool toUnderlying) internal pure returns (bytes memory callData) {
        callData = toUnderlying
            ? abi.encodeCall(IWrappedAToken.withdrawUnderlying, (shares))
            : abi.encodeCall(IWrappedAToken.withdraw, (shares));
    }
}
