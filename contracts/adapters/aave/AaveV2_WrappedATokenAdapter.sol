// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {WrappedAToken} from "../../helpers/aave/AaveV2_WrappedAToken.sol";
import {IAaveV2_WrappedATokenAdapter} from "../../interfaces/aave/IAaveV2_WrappedATokenAdapter.sol";

/// @title Aave V2 Wrapped aToken adapter
/// @notice Implements logic allowing CAs to convert between waTokens, aTokens and underlying tokens
contract AaveV2_WrappedATokenAdapter is AbstractAdapter, IAaveV2_WrappedATokenAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.AAVE_V2_WRAPPED_ATOKEN;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @notice Underlying aToken
    address public immutable override aToken;

    /// @notice Underlying token
    address public immutable override underlying;

    /// @notice Collateral token mask of waToken in the credit manager
    uint256 public immutable override waTokenMask;

    /// @notice Collateral token mask of aToken in the credit manager
    uint256 public immutable override aTokenMask;

    /// @notice Collateral token mask of underlying token in the credit manager
    uint256 public immutable override tokenMask;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _waToken Wrapped aToken address
    constructor(address _creditManager, address _waToken)
        AbstractAdapter(_creditManager, _waToken) // U:[AAVE2W-1]
    {
        waTokenMask = _getMaskOrRevert(targetContract); // U:[AAVE2W-1]

        aToken = WrappedAToken(targetContract).aToken(); // U:[AAVE2W-1]
        aTokenMask = _getMaskOrRevert(aToken); // U:[AAVE2W-1]

        underlying = WrappedAToken(targetContract).underlying(); // U:[AAVE2W-1]
        tokenMask = _getMaskOrRevert(underlying); // U:[AAVE2W-1]
    }

    // -------- //
    // DEPOSITS //
    // -------- //

    /// @notice Deposit given amount of aTokens
    /// @param assets Amount of aTokens to deposit in exchange for waTokens
    function deposit(uint256 assets)
        external
        override
        creditFacadeOnly // U:[AAVE2W-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _deposit(assets, false); // U:[AAVE2W-3]
    }

    /// @notice Deposit all aTokens except the specified amount
    /// @param leftoverAssets Amount of aTokens to leave after the operation
    function depositDiff(uint256 leftoverAssets)
        external
        override
        creditFacadeOnly // U:[AAVE2W-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _depositDiff(false, leftoverAssets); // U:[AAVE2W-4]
    }

    /// @notice Deposit given amount underlying tokens
    /// @param assets Amount of underlying tokens to deposit in exchange for waTokens
    function depositUnderlying(uint256 assets)
        external
        override
        creditFacadeOnly // U:[AAVE2W-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _deposit(assets, true); // U:[AAVE2W-5]
    }

    /// @notice Deposit all underlying tokens except the specified amount
    /// @param leftoverAssets Amount of underlying to leave after the operation
    function depositDiffUnderlying(uint256 leftoverAssets)
        external
        override
        creditFacadeOnly // U:[AAVE2W-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _depositDiff(true, leftoverAssets); // U:[AAVE2W-6]
    }

    /// @dev Internal implementation of `deposit` and `depositUnderlying`
    ///      - underlying / aAoken is approved because waToken contract needs permission to transfer it
    ///      - waToken is enabled after the call
    ///      - underlying / aToken is not disabled after the call because operation doesn't spend the entire balance
    function _deposit(uint256 assets, bool fromUnderlying)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address tokenIn = fromUnderlying ? underlying : aToken;

        _approveToken(tokenIn, type(uint256).max); // U:[AAVE2W-3,5]
        _execute(_encodeDeposit(assets, fromUnderlying)); // U:[AAVE2W-3,5]
        _approveToken(tokenIn, 1); // U:[AAVE2W-3,5]
        (tokensToEnable, tokensToDisable) = (waTokenMask, 0); // U:[AAVE2W-3,5]
    }

    /// @dev Internal implementation of `depositDiff` and `depositDiffUnderlying`
    ///      - underlying / aAoken is approved because wrapped aToken contract needs permission to transfer it
    ///      - waToken is enabled after the call
    ///      - underlying / aToken is disabled after the call if the leftover amount is 0 or 1
    function _depositDiff(bool fromUnderlying, uint256 leftoverAmount)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[AAVE2W-4,6]
        address tokenIn = fromUnderlying ? underlying : aToken;

        uint256 assets = IERC20(tokenIn).balanceOf(creditAccount); // U:[AAVE2W-4,6]
        if (assets <= leftoverAmount) return (0, 0);
        unchecked {
            assets -= leftoverAmount; // U:[AAVE2W-4,6]
        }

        _approveToken(tokenIn, type(uint256).max); // U:[AAVE2W-4,6]
        _execute(_encodeDeposit(assets, fromUnderlying)); // U:[AAVE2W-4,6]
        _approveToken(tokenIn, 1); // U:[AAVE2W-4,6]
        (tokensToEnable, tokensToDisable) =
            (waTokenMask, leftoverAmount > 1 ? 0 : fromUnderlying ? tokenMask : aTokenMask); // U:[AAVE2W-4,6]
    }

    /// @dev Returns data for `WrappedAToken`'s `deposit` or `depositUnderlying` call
    function _encodeDeposit(uint256 assets, bool fromUnderlying) internal pure returns (bytes memory callData) {
        callData = fromUnderlying
            ? abi.encodeCall(WrappedAToken.depositUnderlying, (assets))
            : abi.encodeCall(WrappedAToken.deposit, (assets));
    }

    // ----------- //
    // WITHDRAWALS //
    // ----------- //

    /// @notice Withdraw given amount of waTokens for aTokens
    /// @param shares Amount of waTokens to burn in exchange for aTokens
    function withdraw(uint256 shares)
        external
        override
        creditFacadeOnly // U:[AAVE2W-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdraw(shares, false); // U:[AAVE2W-7]
    }

    /// @notice Withdraw all waTokens to aTokens except the specified amount
    function withdrawDiff(uint256 leftoverShares)
        external
        override
        creditFacadeOnly // U:[AAVE2W-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdrawDiff(false, leftoverShares); // U:[AAVE2W-8]
    }

    /// @notice Withdraw given amount of waTokens for underlying tokens
    /// @param shares Amount of waTokens to burn in exchange for underlying tokens
    function withdrawUnderlying(uint256 shares)
        external
        override
        creditFacadeOnly // U:[AAVE2W-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdraw(shares, true); // U:[AAVE2W-9]
    }

    /// @notice Withdraw all waTokens to underlying tokens except the specified amount
    function withdrawDiffUnderlying(uint256 leftoverShares)
        external
        override
        creditFacadeOnly // U:[AAVE2W-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdrawDiff(true, leftoverShares); // U:[AAVE2W-10]
    }

    /// @dev Internal implementation of `withdraw` and `withdrawUnderlying`
    ///      - waToken is not approved because it doesn't need permission to burn share tokens
    ///      - underlying / aToken is enabled after the call
    ///      - waToken is not disabled after the call because operation doesn't spend the entire balance
    function _withdraw(uint256 shares, bool toUnderlying)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(_encodeWithdraw(shares, toUnderlying)); // U:[AAVE2W-7,9]
        (tokensToEnable, tokensToDisable) = (toUnderlying ? tokenMask : aTokenMask, 0); // U:[AAVE2W-7,9]
    }

    /// @dev Internal implementation of `withdrawDiff` and `withdrawDiffUnderlying`
    ///      - waToken is not approved because it doesn't need permission to burn share tokens
    ///      - underlying / aToken is enabled after the call
    ///      - waToken is disabled after the call if the leftover amount is 0 or 1
    function _withdrawDiff(bool toUnderlying, uint256 leftoverAmount)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[AAVE2W-8,10]

        uint256 shares = IERC20(targetContract).balanceOf(creditAccount); // U:[AAVE2W-8,10]
        if (shares <= leftoverAmount) return (0, 0);
        unchecked {
            shares -= leftoverAmount; // U:[AAVE2W-8,10]
        }

        _execute(_encodeWithdraw(shares, toUnderlying)); // U:[AAVE2W-8,10]
        (tokensToEnable, tokensToDisable) =
            (toUnderlying ? tokenMask : aTokenMask, leftoverAmount <= 1 ? waTokenMask : 0); // U:[AAVE2W-8,10]
    }

    /// @dev Returns data for `WrappedAToken`'s `withdraw` or `withdrawUnderlying` call
    function _encodeWithdraw(uint256 shares, bool toUnderlying) internal pure returns (bytes memory callData) {
        callData = toUnderlying
            ? abi.encodeCall(WrappedAToken.withdrawUnderlying, (shares))
            : abi.encodeCall(WrappedAToken.withdraw, (shares));
    }
}
