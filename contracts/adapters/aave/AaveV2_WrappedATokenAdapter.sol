// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {IAaveV2_WrappedATokenAdapter} from "../../interfaces/aave/IAaveV2_WrappedATokenAdapter.sol";
import {IWrappedATokenV2} from "@gearbox-protocol/oracles-v3/contracts/interfaces/aave/IWrappedATokenV2.sol";

/// @title Aave V2 Wrapped aToken adapter
/// @notice Implements logic allowing CAs to convert between waTokens, aTokens and underlying tokens
contract AaveV2_WrappedATokenAdapter is AbstractAdapter, IAaveV2_WrappedATokenAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.AAVE_V2_WRAPPED_ATOKEN;
    uint16 public constant override _gearboxAdapterVersion = 1;

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

        aToken = IWrappedATokenV2(targetContract).aToken(); // F: [AAV2W-2]
        aTokenMask = _getMaskOrRevert(aToken); // F: [AAV2W-2]

        underlying = IWrappedATokenV2(targetContract).underlying(); // F: [AAV2W-2]
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

    /// @notice Deposit all balance of aTokens, disables aToken
    function depositAll()
        external
        override
        creditFacadeOnly // F: [AAV2W-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _depositAll(false); // F: [AAV2W-5]
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

    /// @notice Deposit all balance of underlying tokens, disables underlying
    function depositAllUnderlying()
        external
        override
        creditFacadeOnly // F: [AAV2W-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _depositAll(true); // F: [AAV2W-5]
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

    /// @dev Internal implementation of `deposit` and `depositUnderlying`
    ///      - underlying / aAoken is approved because wrapped aToken contract needs permission to transfer it
    ///      - waToken is enabled after the call
    ///      - underlying / aToken is disabled after the call because operation spends the entire balance
    function _depositAll(bool fromUnderlying) internal returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        address creditAccount = _creditAccount();
        address tokenIn = fromUnderlying ? underlying : aToken;

        uint256 assets = IERC20(tokenIn).balanceOf(creditAccount);
        if (assets <= 1) return (0, 0);
        unchecked {
            --assets;
        }

        _approveToken(tokenIn, type(uint256).max);
        _execute(_encodeDeposit(assets, fromUnderlying));
        _approveToken(tokenIn, 1);
        (tokensToEnable, tokensToDisable) = (waTokenMask, fromUnderlying ? tokenMask : aTokenMask);
    }

    /// @dev Returns data for `IWrappedATokenV2`'s `deposit` or `depositUnderlying` call
    function _encodeDeposit(uint256 assets, bool fromUnderlying) internal pure returns (bytes memory callData) {
        callData = fromUnderlying
            ? abi.encodeCall(IWrappedATokenV2.depositUnderlying, (assets))
            : abi.encodeCall(IWrappedATokenV2.deposit, (assets));
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

    /// @notice Withdraw all balance of waTokens for aTokens, disables waToken
    function withdrawAll()
        external
        override
        creditFacadeOnly // F: [AAV2W-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdrawAll(false); // F: [AAV2W-7]
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

    /// @notice Withdraw all balance of waTokens for underlying tokens, disables waToken
    function withdrawAllUnderlying()
        external
        override
        creditFacadeOnly // F: [AAV2W-3]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdrawAll(true); // F: [AAV2W-7]
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

    /// @dev Internal implementation of `withdraw` and `withdrawUnderlying`
    ///      - waToken is not approved because it doesn't need permission to burn share tokens
    ///      - underlying / aToken is enabled after the call
    ///      - waToken is disabled after the call because operation spends the entire balance
    function _withdrawAll(bool toUnderlying) internal returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        address creditAccount = _creditAccount();

        uint256 shares = IERC20(targetContract).balanceOf(creditAccount);
        if (shares <= 1) return (0, 0);
        unchecked {
            --shares;
        }

        _execute(_encodeWithdraw(shares, toUnderlying));
        (tokensToEnable, tokensToDisable) = (toUnderlying ? tokenMask : aTokenMask, waTokenMask);
    }

    /// @dev Returns data for `IWrappedATokenV2`'s `withdraw` or `withdrawUnderlying` call
    function _encodeWithdraw(uint256 shares, bool toUnderlying) internal pure returns (bytes memory callData) {
        callData = toUnderlying
            ? abi.encodeCall(IWrappedATokenV2.withdrawUnderlying, (shares))
            : abi.encodeCall(IWrappedATokenV2.withdraw, (shares));
    }
}
