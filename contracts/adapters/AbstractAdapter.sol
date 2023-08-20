// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {CallerNotCreditFacadeException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {ACLTrait} from "@gearbox-protocol/core-v3/contracts/traits/ACLTrait.sol";

/// @title Abstract adapter
/// @dev Inheriting adapters MUST use provided internal functions to perform all operations with credit accounts
abstract contract AbstractAdapter is IAdapter, ACLTrait {
    /// @notice Credit manager the adapter is connected to
    address public immutable override creditManager;

    /// @notice Address provider contract
    address public immutable override addressProvider;

    /// @notice Address of the contract the adapter is interacting with
    address public immutable override targetContract;

    /// @notice Constructor
    /// @param _creditManager Credit manager to connect the adapter to
    /// @param _targetContract Address of the adapted contract
    constructor(address _creditManager, address _targetContract)
        ACLTrait(ICreditManagerV3(_creditManager).addressProvider()) // U:[AA-1A]
        nonZeroAddress(_targetContract) // U:[AA-1A]
    {
        creditManager = _creditManager; // U:[AA-1B]
        addressProvider = ICreditManagerV3(_creditManager).addressProvider(); // U:[AA-1B]
        targetContract = _targetContract; // U:[AA-1B]
    }

    /// @dev Ensures that caller of the function is credit facade connected to the credit manager
    /// @dev Inheriting adapters MUST use this modifier in all external functions that operate on credit accounts
    modifier creditFacadeOnly() {
        _revertIfCallerNotCreditFacade();
        _;
    }

    /// @dev Ensures that caller is credit facade connected to the credit manager
    function _revertIfCallerNotCreditFacade() internal view {
        if (msg.sender != ICreditManagerV3(creditManager).creditFacade()) {
            revert CallerNotCreditFacadeException(); // U:[AA-2]
        }
    }

    /// @dev Ensures that active credit account is set and returns its address
    function _creditAccount() internal view returns (address) {
        return ICreditManagerV3(creditManager).getActiveCreditAccountOrRevert(); // U:[AA-3]
    }

    /// @dev Ensures that token is registered as collateral in the credit manager and returns its mask
    function _getMaskOrRevert(address token) internal view returns (uint256 tokenMask) {
        tokenMask = ICreditManagerV3(creditManager).getTokenMaskOrRevert(token); // U:[AA-4]
    }

    /// @dev Approves target contract to spend given token from the active credit account
    ///      Reverts if active credit account is not set or token is not registered as collateral
    /// @param token Token to approve
    /// @param amount Amount to approve
    function _approveToken(address token, uint256 amount) internal {
        ICreditManagerV3(creditManager).approveCreditAccount(token, amount); // U:[AA-5]
    }

    /// @dev Executes an external call from the active credit account to the target contract
    ///      Reverts if active credit account is not set
    /// @param callData Data to call the target contract with
    /// @return result Call result
    function _execute(bytes memory callData) internal returns (bytes memory result) {
        return ICreditManagerV3(creditManager).execute(callData); // U:[AA-6]
    }

    /// @dev Executes a swap operation without input token approval
    ///      Reverts if active credit account is not set or any of passed tokens is not registered as collateral
    /// @param tokenIn Input token that credit account spends in the call
    /// @param tokenOut Output token that credit account receives after the call
    /// @param callData Data to call the target contract with
    /// @param disableTokenIn Whether `tokenIn` should be disabled after the call
    ///        (for operations that spend the entire account's balance of the input token)
    /// @return tokensToEnable Bit mask of tokens that should be enabled after the call
    /// @return tokensToDisable Bit mask of tokens that should be disabled after the call
    /// @return result Call result
    function _executeSwapNoApprove(address tokenIn, address tokenOut, bytes memory callData, bool disableTokenIn)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable, bytes memory result)
    {
        tokensToEnable = _getMaskOrRevert(tokenOut); // U:[AA-7]
        uint256 tokenInMask = _getMaskOrRevert(tokenIn);
        if (disableTokenIn) tokensToDisable = tokenInMask; // U:[AA-7]
        result = _execute(callData); // U:[AA-7]
    }

    /// @dev Executes a swap operation with maximum input token approval, and revokes approval after the call
    ///      Reverts if active credit account is not set or any of passed tokens is not registered as collateral
    /// @param tokenIn Input token that credit account spends in the call
    /// @param tokenOut Output token that credit account receives after the call
    /// @param callData Data to call the target contract with
    /// @param disableTokenIn Whether `tokenIn` should be disabled after the call
    ///        (for operations that spend the entire account's balance of the input token)
    /// @return tokensToEnable Bit mask of tokens that should be enabled after the call
    /// @return tokensToDisable Bit mask of tokens that should be disabled after the call
    /// @return result Call result
    /// @custom:expects Credit manager reverts when trying to approve non-collateral token
    function _executeSwapSafeApprove(address tokenIn, address tokenOut, bytes memory callData, bool disableTokenIn)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable, bytes memory result)
    {
        tokensToEnable = _getMaskOrRevert(tokenOut); // U:[AA-8]
        if (disableTokenIn) tokensToDisable = _getMaskOrRevert(tokenIn); // U:[AA-8]
        _approveToken(tokenIn, type(uint256).max); // U:[AA-8]
        result = _execute(callData); // U:[AA-8]
        _approveToken(tokenIn, 1); // U:[AA-8]
    }
}
