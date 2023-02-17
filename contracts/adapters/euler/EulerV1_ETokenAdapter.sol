// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AbstractAdapter } from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";
import { AdapterType } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

import { IEToken } from "../../integrations/euler/IEToken.sol";
import { IEulerV1_ETokenAdapter } from "../../interfaces/euler/IEulerV1_ETokenAdapter.sol";

/// @title Euler eToken adapter
/// @notice Implements logic for CAs to interact with Euler's eTokens
contract EulerV1_ETokenAdapter is AbstractAdapter, IEulerV1_ETokenAdapter {
    /// @notice Address of the eToken's underlying token
    address public immutable override underlying;

    AdapterType public constant _gearboxAdapterType =
        AdapterType.EULER_V1_ETOKEN;
    uint16 public constant _gearboxAdapterVersion = 1;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _eToken eToken address
    constructor(
        address _creditManager,
        address _eToken
    ) AbstractAdapter(_creditManager, _eToken) {
        underlying = IEToken(_eToken).underlyingAsset();

        if (creditManager.tokenMasksMap(underlying) == 0)
            revert TokenIsNotInAllowedList(underlying);

        if (creditManager.tokenMasksMap(targetContract) == 0)
            revert TokenIsNotInAllowedList(targetContract);
    }

    /// -------- ///
    /// DEPOSITS ///
    /// -------- ///

    /// @notice Deposit underlying tokens into Euler in exchange for eTokens
    /// @param amount Amount of underlying tokens to deposit, set to `type(uint256).max`
    ///        to deposit full amount (in this case, underlying will be disabled)
    /// @dev First param (`subAccountId`) is ignored since CAs can't use Euler's sub-accounts
    function deposit(
        uint256,
        uint256 amount
    ) external override creditFacadeOnly {
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
    ///      - Calls `_executeSwapSafeApprove` because Euler needs permission to transfer underlying
    ///      - `tokenIn` is eToken's underlying token
    ///      - `tokenOut` is eToken
    ///      - `disableTokenIn` is set to false because operation doesn't spend the entire balance
    function _deposit(uint256 amount) internal {
        _executeSwapSafeApprove(
            underlying,
            targetContract,
            _encodeDeposit(amount),
            false
        );
    }

    /// @dev Internal implementation of `depositAll` functionality
    ///      - Calls `_executeSwapSafeApprove` because Euler needs permission to transfer underlying
    ///      - `tokenIn` is eToken's underlying token
    ///      - `tokenOut` is eToken
    ///      - `disableTokenIn` is set to true because operation spends the entire balance
    function _depositAll() internal {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );
        uint256 balance = IERC20(underlying).balanceOf(creditAccount);
        if (balance <= 1) return;

        uint256 amount;
        unchecked {
            amount = balance - 1;
        }
        _executeSwapSafeApprove(
            creditAccount,
            underlying,
            targetContract,
            _encodeDeposit(amount),
            true
        );
    }

    /// @dev Returns calldata for `IEToken.deposit` call
    function _encodeDeposit(
        uint256 amount
    ) internal pure returns (bytes memory callData) {
        return abi.encodeCall(IEToken.deposit, (0, amount));
    }

    /// ----------- ///
    /// WITHDRAWALS ///
    /// ----------- ///

    /// @notice Withdraw underlying tokens from Euler and burn eTokens
    /// @param amount Amount of underlying tokens to withdraw, set to `type(uint256).max`
    ///        to withdraw full amount (in this case, eToken will be disabled)
    /// @dev First param (`subAccountId`) is ignored since CAs can't use Euler's sub-accounts
    function withdraw(
        uint256,
        uint256 amount
    ) external override creditFacadeOnly {
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
    ///      - Calls `_executeSwapNoApprove` because Euler doesn't need permission to burn eTokens
    ///      - `tokenIn` is eToken
    ///      - `tokenOut` is eToken's underlying token
    ///      - `disableTokenIn` is set to false because operation doesn't spend the entire balance
    function _withdraw(uint256 amount) internal {
        _executeSwapNoApprove(
            targetContract,
            underlying,
            _encodeWithdraw(amount),
            false
        );
    }

    /// @dev Implementation of `withdrawAll` functionality
    ///      - Calls `_executeSwapNoApprove` because Euler doesn't need permission to burn eTokens
    ///      - `tokenIn` is eToken
    ///      - `tokenOut` is eToken's underlying token
    ///      - `disableTokenIn` is set to true because operation spends the entire balance
    function _withdrawAll() internal {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );
        // NOTE: there is no guaranteed way to keep precisely 1 eToken on the balance
        // so we're keeping an equivalent of 1 underlying token
        uint256 balance = IEToken(targetContract).balanceOfUnderlying(
            creditAccount
        );
        if (balance <= 1) return;

        uint256 amount;
        unchecked {
            amount = balance - 1;
        }
        _executeSwapNoApprove(
            creditAccount,
            targetContract,
            underlying,
            _encodeWithdraw(amount),
            true
        );
    }

    /// @dev Returns calldata for `IEToken.withdraw` call
    function _encodeWithdraw(
        uint256 amount
    ) internal pure returns (bytes memory callData) {
        return abi.encodeCall(IEToken.withdraw, (0, amount));
    }
}
