// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

import {ILendingPool} from "../../integrations/aave/ILendingPool.sol";
import {IAaveV2_LendingPoolAdapter} from "../../interfaces/aave/IAaveV2_LendingPoolAdapter.sol";

/// @title Aave V2 LendingPool adapter
/// @notice Implements logic for CAs to interact with Aave's lending pool
contract AaveV2_LendingPoolAdapter is AbstractAdapter, IAaveV2_LendingPoolAdapter {
    AdapterType public constant _gearboxAdapterType = AdapterType.AAVE_V2_LENDING_POOL;
    uint16 public constant _gearboxAdapterVersion = 1;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _lendingPool Lending pool address
    constructor(address _creditManager, address _lendingPool) AbstractAdapter(_creditManager, _lendingPool) {}

    /// @dev Returns aToken address for given underlying token
    function _aToken(address underlying) internal view returns (address) {
        return ILendingPool(targetContract).getReserveData(underlying).aTokenAddress;
    }

    /// -------- ///
    /// DEPOSITS ///
    /// -------- ///

    /// @notice Deposit underlying tokens into Aave in exchange for aTokens
    /// @param asset Address of underlying token to deposit
    /// @param amount Amount of underlying tokens to deposit
    /// @dev Last two parameters are ignored as `onBehalfOf` can only be credit account,
    ///      and `referralCode` is set to zero
    function deposit(address asset, uint256 amount, address, uint16) external override creditFacadeOnly {
        address creditAccount = _creditAccount();
        _deposit(creditAccount, asset, amount, false);
    }

    /// @notice Deposit all underlying tokens into Aave in exchange for aTokens, disables underlying
    /// @param asset Address of underlying token to deposit
    function depositAll(address asset) external override creditFacadeOnly {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(asset).balanceOf(creditAccount);
        if (balance <= 1) return;

        uint256 amount;
        unchecked {
            amount = balance - 1;
        }
        _deposit(creditAccount, asset, amount, true);
    }

    /// @dev Internal implementation of `deposit` and `depositAll` functions
    ///      - Calls `_executeSwapSafeApprove` because lending pool needs approval to transfer underlying
    ///      - `tokenIn` is aToken's underlying token
    ///      - `tokenOut` is aToken
    ///      - `disableTokenIn` is only true when called from `depositAll` because in this case operation
    ///      spends the entire balance
    function _deposit(address creditAccount, address asset, uint256 amount, bool disableTokenIn) internal {
        _executeSwapSafeApprove(
            creditAccount,
            asset,
            _aToken(asset),
            abi.encodeCall(ILendingPool.deposit, (asset, amount, creditAccount, 0)),
            disableTokenIn
        );
    }

    /// ----------- ///
    /// WITHDRAWALS ///
    /// ----------- ///

    /// @notice Withdraw underlying tokens from Aave and burn aTokens
    /// @param asset Address of underlying token to deposit
    /// @param amount Amount of underlying tokens to withdraw
    ///        If `type(uint256).max`, will withdraw the full amount
    /// @dev Last parameter is ignored because underlying recepient can only be credit account
    function withdraw(address asset, uint256 amount, address) external override creditFacadeOnly {
        address creditAccount = _creditAccount();
        if (amount == type(uint256).max) {
            _withdrawAll(creditAccount, asset);
        } else {
            _withdraw(creditAccount, asset, amount);
        }
    }

    /// @notice Withdraw all underlying tokens from Aave and burn aTokens, disables aToken
    /// @param asset Address of underlying token to withdraw
    function withdrawAll(address asset) external override creditFacadeOnly {
        address creditAccount = _creditAccount();
        _withdrawAll(creditAccount, asset);
    }

    /// @dev Internal implementation of `withdraw` functionality
    ///      - Calls `_executeSwapNoApprove` because lending pool doesn't need permission to burn aTokens
    ///      - `tokenIn` is aToken
    ///      - `tokenOut` is aToken's underlying token
    ///      - `disableTokenIn` is false because operation doesn't generally spend the entire balance
    function _withdraw(address creditAccount, address asset, uint256 amount) internal {
        _executeSwapNoApprove(
            creditAccount, _aToken(asset), asset, _encodeWithdraw(creditAccount, asset, amount), false
        );
    }

    /// @dev Internal implementation of `withdrawAll` functionality
    ///      - Calls `_executeSwapNoApprove` because lending pool doesn't need permission to burn aTokens
    ///      - `tokenIn` is aToken
    ///      - `tokenOut` is aToken's underlying token
    ///      - `disableTokenIn` is true because operation spends the entire balance
    function _withdrawAll(address creditAccount, address asset) internal {
        address aToken = _aToken(asset);
        uint256 balance = IERC20(aToken).balanceOf(creditAccount);
        if (balance <= 1) return;

        uint256 amount;
        unchecked {
            amount = balance - 1;
        }

        _executeSwapNoApprove(creditAccount, aToken, asset, _encodeWithdraw(creditAccount, asset, amount), true);
    }

    /// @dev Returns calldata for `ILendingPool.withdraw` call
    function _encodeWithdraw(address creditAccount, address asset, uint256 amount)
        internal
        pure
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(ILendingPool.withdraw, (asset, amount, creditAccount));
    }
}
