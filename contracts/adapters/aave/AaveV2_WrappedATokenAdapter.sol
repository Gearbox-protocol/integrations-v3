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
    constructor(address _creditManager, address _waToken) AbstractAdapter(_creditManager, _waToken) {
        waTokenMask = _getMaskOrRevert(targetContract); // F: [AAV2W-1, AAV2W-2]

        aToken = WrappedAToken(targetContract).aToken(); // F: [AAV2W-2]
        aTokenMask = _getMaskOrRevert(aToken); // F: [AAV2W-2]

        underlying = WrappedAToken(targetContract).underlying(); // F: [AAV2W-2]
        tokenMask = _getMaskOrRevert(underlying); // F: [AAV2W-2]
    }

    // -------- //
    // DEPOSITS //
    // -------- //

    /// @notice Deposit given amount of aTokens
    /// @param assets Amount of aTokens to deposit in exchange for waTokens
    function deposit(uint256 assets)
        external
        override
        creditFacadeOnly // F: [AAV2W-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _deposit(assets, false); // F: [AAV2W-4]
    }

    /// @notice Deposit all aTokens except the specified amount
    /// @param leftoverAssets Amount of aTokens to leave after the operation
    function depositDiff(uint256 leftoverAssets)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _depositDiff(false, leftoverAssets);
    }

    /// @notice Deposit all balance of aTokens, disables aToken
    function depositAll()
        external
        override
        creditFacadeOnly // F: [AAV2W-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _depositDiff(false, 1); // F: [AAV2W-5]
    }

    /// @notice Deposit given amount underlying tokens
    /// @param assets Amount of underlying tokens to deposit in exchange for waTokens
    function depositUnderlying(uint256 assets)
        external
        override
        creditFacadeOnly // F: [AAV2W-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _deposit(assets, true); // F: [AAV2W-4]
    }

    /// @notice Deposit all underlying tokens except the specified amount
    /// @param leftoverAssets Amount of underlying to leave after the operation
    function depositDiffUnderlying(uint256 leftoverAssets)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _depositDiff(true, leftoverAssets);
    }

    /// @notice Deposit all balance of underlying tokens, disables underlying
    function depositAllUnderlying()
        external
        override
        creditFacadeOnly // F: [AAV2W-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _depositDiff(true, 1); // F: [AAV2W-5]
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

        _approveToken(tokenIn, type(uint256).max);
        _execute(_encodeDeposit(assets, fromUnderlying));
        _approveToken(tokenIn, 1);
        (tokensToEnable, tokensToDisable) = (waTokenMask, 0);
    }

    /// @dev Internal implementation of `depositAll`, `depositDiff`, `depositAllUnderlying` and `depositDiffUnderlying`
    ///      - underlying / aAoken is approved because wrapped aToken contract needs permission to transfer it
    ///      - waToken is enabled after the call
    ///      - underlying / aToken is disabled after the call if the leftover amount is 0 or 1
    function _depositDiff(bool fromUnderlying, uint256 leftoverAmount)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();
        address tokenIn = fromUnderlying ? underlying : aToken;

        uint256 assets = IERC20(tokenIn).balanceOf(creditAccount);
        if (assets <= leftoverAmount) return (0, 0);
        unchecked {
            assets -= leftoverAmount;
        }

        _approveToken(tokenIn, type(uint256).max);
        _execute(_encodeDeposit(assets, fromUnderlying));
        _approveToken(tokenIn, 1);
        (tokensToEnable, tokensToDisable) =
            (waTokenMask, leftoverAmount > 1 ? 0 : fromUnderlying ? tokenMask : aTokenMask);
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
        creditFacadeOnly // F: [AAV2W-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdraw(shares, false); // F: [AAV2W-6]
    }

    /// @notice Withdraw all waTokens to aTokens except the specified amount
    function withdrawDiff(uint256 leftoverShares)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdrawDiff(false, leftoverShares);
    }

    /// @notice Withdraw all balance of waTokens for aTokens, disables waToken
    function withdrawAll()
        external
        override
        creditFacadeOnly // F: [AAV2W-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdrawDiff(false, 1); // F: [AAV2W-7]
    }

    /// @notice Withdraw given amount of waTokens for underlying tokens
    /// @param shares Amount of waTokens to burn in exchange for underlying tokens
    function withdrawUnderlying(uint256 shares)
        external
        override
        creditFacadeOnly // F: [AAV2W-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdraw(shares, true); // F: [AAV2W-6]
    }

    /// @notice Withdraw all waTokens to underlying tokens except the specified amount
    function withdrawDiffUnderlying(uint256 leftoverShares)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdrawDiff(true, leftoverShares);
    }

    /// @notice Withdraw all balance of waTokens for underlying tokens, disables waToken
    function withdrawAllUnderlying()
        external
        override
        creditFacadeOnly // F: [AAV2W-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdrawDiff(true, 1); // F: [AAV2W-7]
    }

    /// @dev Internal implementation of `withdraw` and `withdrawUnderlying`
    ///      - waToken is not approved because it doesn't need permission to burn share tokens
    ///      - underlying / aToken is enabled after the call
    ///      - waToken is not disabled after the call because operation doesn't spend the entire balance
    function _withdraw(uint256 shares, bool toUnderlying)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(_encodeWithdraw(shares, toUnderlying));
        (tokensToEnable, tokensToDisable) = (toUnderlying ? tokenMask : aTokenMask, 0);
    }

    /// @dev Internal implementation of `withdrawAll`, `withdrawAllUnderlying`, `withdrawDiff` and `withdrawDiffUnderlying`
    ///      - waToken is not approved because it doesn't need permission to burn share tokens
    ///      - underlying / aToken is enabled after the call
    ///      - waToken is disabled after the call because operation spends the entire balance
    function _withdrawDiff(bool toUnderlying, uint256 leftoverAmount)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();

        uint256 shares = IERC20(targetContract).balanceOf(creditAccount);
        if (shares <= leftoverAmount) return (0, 0);
        unchecked {
            shares -= leftoverAmount;
        }

        _execute(_encodeWithdraw(shares, toUnderlying));
        (tokensToEnable, tokensToDisable) =
            (toUnderlying ? tokenMask : aTokenMask, leftoverAmount <= 1 ? waTokenMask : 0);
    }

    /// @dev Returns data for `WrappedAToken`'s `withdraw` or `withdrawUnderlying` call
    function _encodeWithdraw(uint256 shares, bool toUnderlying) internal pure returns (bytes memory callData) {
        callData = toUnderlying
            ? abi.encodeCall(WrappedAToken.withdrawUnderlying, (shares))
            : abi.encodeCall(WrappedAToken.withdraw, (shares));
    }
}
