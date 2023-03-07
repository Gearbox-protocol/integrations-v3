// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

import {IEToken} from "../../integrations/euler/IEToken.sol";
import {IEulerV1_ETokenAdapter} from "../../interfaces/euler/IEulerV1_ETokenAdapter.sol";

/// @title Euler eToken adapter
/// @notice Implements logic allowing CAs to interact with Euler's eTokens
contract EulerV1_ETokenAdapter is AbstractAdapter, IEulerV1_ETokenAdapter {
    /// @notice Address of the eToken's underlying token
    address public immutable override underlying;

    /// @notice Collateral token mask of underlying token in the credit manager
    uint256 public immutable override tokenMask;

    /// @notice Collateral token mask of eToken in the credit manager
    uint256 public immutable override eTokenMask;

    AdapterType public constant override _gearboxAdapterType = AdapterType.EULER_V1_ETOKEN;
    uint16 public constant override _gearboxAdapterVersion = 1;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _eToken eToken address
    constructor(address _creditManager, address _eToken) AbstractAdapter(_creditManager, _eToken) {
        underlying = IEToken(_eToken).underlyingAsset();

        tokenMask = creditManager.tokenMasksMap(underlying);
        if (tokenMask == 0) {
            revert TokenIsNotInAllowedList(underlying);
        }

        eTokenMask = creditManager.tokenMasksMap(targetContract);
        if (eTokenMask == 0) {
            revert TokenIsNotInAllowedList(targetContract);
        }
    }

    /// -------- ///
    /// DEPOSITS ///
    /// -------- ///

    /// @notice Deposit underlying tokens into Euler in exchange for eTokens
    /// @param amount Amount of underlying tokens to deposit, set to `type(uint256).max`
    ///        to deposit full amount (in this case, underlying will be disabled)
    /// @dev First param (`subAccountId`) is ignored since CAs can't use Euler's sub-accounts
    function deposit(uint256, uint256 amount) external override creditFacadeOnly {
        if (amount == type(uint256).max) {
            _depositAll();
        } else {
            _deposit(amount);
        }
    }

    /// @notice Deposit all underlying tokens into Euler in exchange for eTokens, disables underlying
    function depositAll() external override creditFacadeOnly {
        _depositAll();
    }

    /// @dev Internal implementation of `deposit` functionality
    ///      - underlying is approved before the call because Euler needs permission to transfer it
    ///      - eToken is enabled after the call
    ///      - underlying is not disabled because operation doesn't spend the entire balance
    function _deposit(uint256 amount) internal {
        _approveToken(underlying, type(uint256).max);
        _execute(_encodeDeposit(amount));
        _approveToken(underlying, 1);
        _changeEnabledTokens(eTokenMask, 0);
    }

    /// @dev Internal implementation of `depositAll` functionality
    ///      - underlying is approved before the call because Euler needs permission to transfer it
    ///      - eToken is enabled after the call
    ///      - underlying is disabled because operation spends the entire balance
    function _depositAll() internal {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(underlying).balanceOf(creditAccount);
        if (balance <= 1) return;

        uint256 amount;
        unchecked {
            amount = balance - 1;
        }

        _approveToken(underlying, type(uint256).max);
        _execute(_encodeDeposit(amount));
        _approveToken(underlying, 1);
        _changeEnabledTokens(eTokenMask, tokenMask);
    }

    /// @dev Returns calldata for `IEToken.deposit` call
    function _encodeDeposit(uint256 amount) internal pure returns (bytes memory callData) {
        return abi.encodeCall(IEToken.deposit, (0, amount));
    }

    /// ----------- ///
    /// WITHDRAWALS ///
    /// ----------- ///

    /// @notice Withdraw underlying tokens from Euler and burn eTokens
    /// @param amount Amount of underlying tokens to withdraw, set to `type(uint256).max`
    ///        to withdraw full amount (in this case, eToken will be disabled)
    /// @dev First param (`subAccountId`) is ignored since CAs can't use Euler's sub-accounts
    function withdraw(uint256, uint256 amount) external override creditFacadeOnly {
        if (amount == type(uint256).max) {
            _withdrawAll();
        } else {
            _withdraw(amount);
        }
    }

    /// @notice Withdraw all underlying tokens from Euler and burn eTokens, disables eToken
    function withdrawAll() external override creditFacadeOnly {
        _withdrawAll();
    }

    /// @dev Internal implementation of `withdraw` functionality
    ///      - eToken is not approved because Euler doesn't need permission to burn eTokens
    ///      - underlying is enabled after the call
    ///      - eToken is not disabled because oepration doesn't spend the entire balance balance
    function _withdraw(uint256 amount) internal {
        _execute(_encodeWithdraw(amount));
        _changeEnabledTokens(tokenMask, 0);
    }

    /// @dev Implementation of `withdrawAll` functionality
    ///      - eToken is not approved because Euler doesn't need permission to burn eTokens
    ///      - underlying is enabled after the call
    ///      - eToken is disabled because operation spends the entire balance
    function _withdrawAll() internal {
        address creditAccount = _creditAccount();
        // NOTE: there is no guaranteed way to keep precisely 1 eToken on the balance
        // so we're keeping an equivalent of 1 underlying token
        uint256 balance = IEToken(targetContract).balanceOfUnderlying(creditAccount);
        if (balance <= 1) return;

        uint256 amount;
        unchecked {
            amount = balance - 1;
        }

        _execute(_encodeWithdraw(amount));
        _changeEnabledTokens(tokenMask, eTokenMask);
    }

    /// @dev Returns calldata for `IEToken.withdraw` call
    function _encodeWithdraw(uint256 amount) internal pure returns (bytes memory callData) {
        return abi.encodeCall(IEToken.withdraw, (0, amount));
    }
}
