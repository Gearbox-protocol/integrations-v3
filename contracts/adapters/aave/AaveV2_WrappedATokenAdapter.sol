// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AbstractAdapter } from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";
import { AdapterType } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

import { IWrappedAToken } from "../../interfaces/aave/IWrappedAToken.sol";
import { IAaveV2_WrappedATokenAdapter } from "../../interfaces/aave/IAaveV2_WrappedATokenAdapter.sol";

/// @title Aave V2 Wrapped aToken adapter
/// @notice Implements logic for CAs to convert between waTokens, aTokens and underlying tokens
contract AaveV2_WrappedATokenAdapter is
    AbstractAdapter,
    IAaveV2_WrappedATokenAdapter
{
    /// @notice Underlying aToken
    address public immutable override aToken;

    /// @notice Underlying token
    address public immutable override underlying;

    AdapterType public constant _gearboxAdapterType =
        AdapterType.AAVE_V2_WRAPPED_ATOKEN;
    uint16 public constant _gearboxAdapterVersion = 1;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _waToken Wrapped aToken address
    constructor(
        address _creditManager,
        address _waToken
    ) AbstractAdapter(_creditManager, _waToken) {
        if (creditManager.tokenMasksMap(targetContract) == 0)
            revert TokenIsNotInAllowedList(targetContract);

        aToken = address(IWrappedAToken(targetContract).aToken());
        if (creditManager.tokenMasksMap(aToken) == 0)
            revert TokenIsNotInAllowedList(aToken);

        underlying = address(IWrappedAToken(targetContract).underlying());
        if (creditManager.tokenMasksMap(underlying) == 0)
            revert TokenIsNotInAllowedList(underlying);
    }

    /// -------- ///
    /// DEPOSITS ///
    /// -------- ///

    /// @notice Deposit given amount of aTokens
    /// @param assets Amount of aTokens to deposit in exchange for waTokens
    function deposit(uint256 assets) external override creditFacadeOnly {
        _deposit(assets, false);
    }

    /// @notice Deposit all balance of aTokens
    function depositAll() external override creditFacadeOnly {
        _depositAll(false);
    }

    /// @notice Deposit given amount underlying tokens
    /// @param assets Amount of underlying tokens to deposit in exchange for waTokens
    function depositUnderlying(
        uint256 assets
    ) external override creditFacadeOnly {
        _deposit(assets, true);
    }

    /// @notice Deposit all balance of underlying tokens
    function depositAllUnderlying() external override creditFacadeOnly {
        _depositAll(true);
    }

    /// @dev Internal implementation of `deposit` and `depositUnderlying`
    ///      - Calls `_executeSwapSafeApprove` because waToken needs approval to transfer `tokenIn`
    ///      - `tokenIn` is aToken or underlying
    ///      - `tokenOut` is waToken
    ///      - `disableTokenIn` is false because operation doesn't spend the entire balance
    function _deposit(uint256 assets, bool fromUnderlying) internal {
        _executeSwapSafeApprove(
            fromUnderlying ? underlying : aToken,
            targetContract,
            _encodeDeposit(assets, fromUnderlying),
            false
        );
    }

    /// @dev Internal implementation of `depositAll` and `depositAllUnderlying`
    ///      - Calls `_executeSwapSafeApprove` because waToken needs approval to transfer `tokenIn`
    ///      - `tokenIn` is aToken or underlying
    ///      - `tokenOut` is waToken
    ///      - `disableTokenIn` is true because operation spends the entire balance
    function _depositAll(bool fromUnderlying) internal {
        address creditAccount = _creditAccount();
        address tokenIn = fromUnderlying ? underlying : aToken;
        uint256 balance = IERC20(tokenIn).balanceOf(creditAccount);
        if (balance <= 1) return;

        uint256 assets;
        unchecked {
            assets = balance - 1;
        }

        _executeSwapSafeApprove(
            creditAccount,
            tokenIn,
            targetContract,
            _encodeDeposit(assets, fromUnderlying),
            true
        );
    }

    /// @dev Returns data for `IWrappedAToken`'s `deposit` or `depositUnderlying` call
    function _encodeDeposit(
        uint256 assets,
        bool fromUnderlying
    ) internal pure returns (bytes memory callData) {
        callData = fromUnderlying
            ? abi.encodeCall(IWrappedAToken.depositUnderlying, (assets))
            : abi.encodeCall(IWrappedAToken.deposit, (assets));
    }

    /// ----------- ///
    /// WITHDRAWALS ///
    /// ----------- ///

    /// @notice Withdraw given amount of waTokens for aTokens
    /// @param shares Amount of waTokens to burn in exchange for aTokens
    function withdraw(uint256 shares) external override creditFacadeOnly {
        _withdraw(shares, false);
    }

    /// @notice Withdraw all balance of waTokens for aTokens
    function withdrawAll() external override creditFacadeOnly {
        _withdrawAll(false);
    }

    /// @notice Withdraw given amount of waTokens for underlying tokens
    /// @param shares Amount of waTokens to burn in exchange for underlying tokens
    function withdrawUnderlying(
        uint256 shares
    ) external override creditFacadeOnly {
        _withdraw(shares, true);
    }

    /// @notice Withdraw all balance of waTokens for underlying tokens
    function withdrawAllUnderlying() external override creditFacadeOnly {
        _withdrawAll(true);
    }

    /// @dev Internal implementation of `withdraw` and `withdrawUnderlying`
    ///      - Calls `_executeSwapNoApprove` since waToken needs no approval to burn tokens
    ///      - `tokenIn` is waToken
    ///      - `tokenOut` is aToken or underlying
    ///      - `disableTokenIn` is false because operation doesn't spend the entire balance
    function _withdraw(uint256 shares, bool toUnderlying) internal {
        _executeSwapNoApprove(
            targetContract,
            toUnderlying ? underlying : aToken,
            _encodeWithdraw(shares, toUnderlying),
            false
        );
    }

    /// @dev Internal implementation of `withdrawAll` and `withdrawAllUnderlying`
    ///      - Calls `_executeSwapNoApprove` since waToken needs no approval to burn tokens
    ///      - `tokenIn` is waToken
    ///      - `tokenOut` is aToken or underlying
    ///      - `disableTokenIn` is true because operation spends the entire balance
    function _withdrawAll(bool toUnderlying) internal {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(targetContract).balanceOf(creditAccount);
        if (balance <= 1) return;

        uint256 shares;
        unchecked {
            shares = balance - 1;
        }

        _executeSwapNoApprove(
            creditAccount,
            targetContract,
            toUnderlying ? underlying : aToken,
            _encodeWithdraw(shares, toUnderlying),
            true
        );
    }

    /// @dev Returns data for `IWrappedAToken`'s `withdraw` or `withdrawUnderlying` call
    function _encodeWithdraw(
        uint256 shares,
        bool toUnderlying
    ) internal pure returns (bytes memory callData) {
        callData = toUnderlying
            ? abi.encodeCall(IWrappedAToken.withdrawUnderlying, (shares))
            : abi.encodeCall(IWrappedAToken.withdraw, (shares));
    }
}
