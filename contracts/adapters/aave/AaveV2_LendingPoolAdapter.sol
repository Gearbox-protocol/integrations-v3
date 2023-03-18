// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "../../interfaces/IAdapter.sol";

import {ILendingPool} from "../../integrations/aave/ILendingPool.sol";
import {IAaveV2_LendingPoolAdapter} from "../../interfaces/aave/IAaveV2_LendingPoolAdapter.sol";

/// @title Aave V2 LendingPool adapter
/// @notice Implements logic allowing CAs to interact with Aave's lending pool
contract AaveV2_LendingPoolAdapter is AbstractAdapter, IAaveV2_LendingPoolAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.AAVE_V2_LENDING_POOL;
    uint16 public constant override _gearboxAdapterVersion = 1;

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

    /// @inheritdoc IAaveV2_LendingPoolAdapter
    function deposit(address asset, uint256 amount, address, uint16) external override creditFacadeOnly {
        address creditAccount = _creditAccount();
        _deposit(creditAccount, asset, amount, false);
    }

    /// @inheritdoc IAaveV2_LendingPoolAdapter
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
    ///      - using `_executeSwap` because need to check if tokens are recognized by the system
    ///      - underlying is approved before the call because lending pool needs permission to transfer it
    ///      - aToken is enabled after the call
    ///      - underlying is only disabled when depositing the entire balance
    function _deposit(address creditAccount, address asset, uint256 amount, bool disableTokenIn) internal {
        _executeSwapSafeApprove(
            asset,
            _aToken(asset),
            abi.encodeCall(ILendingPool.deposit, (asset, amount, creditAccount, 0)),
            disableTokenIn
        );
    }

    /// ----------- ///
    /// WITHDRAWALS ///
    /// ----------- ///

    /// @inheritdoc IAaveV2_LendingPoolAdapter
    function withdraw(address asset, uint256 amount, address) external override creditFacadeOnly {
        address creditAccount = _creditAccount();
        if (amount == type(uint256).max) {
            _withdrawAll(creditAccount, asset);
        } else {
            _withdraw(creditAccount, asset, amount);
        }
    }

    /// @inheritdoc IAaveV2_LendingPoolAdapter
    function withdrawAll(address asset) external override creditFacadeOnly {
        address creditAccount = _creditAccount();
        _withdrawAll(creditAccount, asset);
    }

    /// @dev Internal implementation of `withdraw` functionality
    ///      - using `_executeSwap` because need to check if tokens are recognized by the system
    ///      - aToken is not approved before the call because lending pool doesn't need permission to burn it
    ///      - underlying is enabled after the call
    ///      - aToken is not disabled because operation doesn't spend the entire balance
    function _withdraw(address creditAccount, address asset, uint256 amount) internal {
        _executeSwapNoApprove(_aToken(asset), asset, _encodeWithdraw(creditAccount, asset, amount), false);
    }

    /// @dev Internal implementation of `withdrawAll` functionality
    ///      - using `_executeSwap` because need to check if tokens are recognized by the system
    ///      - aToken is not approved before the call because lending pool doesn't need permission to burn it
    ///      - underlying is enabled after the call
    ///      - aToken is not disabled because operation spends the entire balance
    function _withdrawAll(address creditAccount, address asset) internal {
        address aToken = _aToken(asset);
        uint256 balance = IERC20(aToken).balanceOf(creditAccount);
        if (balance <= 1) return;

        uint256 amount;
        unchecked {
            amount = balance - 1;
        }

        _executeSwapNoApprove(aToken, asset, _encodeWithdraw(creditAccount, asset, amount), true);
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
