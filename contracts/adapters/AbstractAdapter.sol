// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {IStateSerializer} from "../interfaces/IStateSerializer.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {PoolV3} from "@gearbox-protocol/core-v3/contracts/pool/PoolV3.sol";
import {CallerNotCreditFacadeException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {ACLTrait} from "@gearbox-protocol/core-v3/contracts/traits/ACLTrait.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";

/// @title Abstract adapter
/// @dev Inheriting adapters MUST use provided internal functions to perform all operations with credit accounts
abstract contract AbstractAdapter is IAdapter, IStateSerializer, ACLTrait, SanityCheckTrait {
    /// @notice Credit manager the adapter is connected to
    address public immutable override creditManager;

    /// @notice Address of the contract the adapter is interacting with
    address public immutable override targetContract;

    /// @notice Constructor
    /// @param _creditManager Credit manager to connect the adapter to
    /// @param _targetContract Address of the adapted contract
    constructor(address _creditManager, address _targetContract)
        ACLTrait(PoolV3(ICreditManagerV3(_creditManager).pool()).acl())
        nonZeroAddress(_targetContract)
    {
        creditManager = _creditManager;
        targetContract = _targetContract;
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
            revert CallerNotCreditFacadeException();
        }
    }

    /// @dev Ensures that active credit account is set and returns its address
    function _creditAccount() internal view returns (address) {
        return ICreditManagerV3(creditManager).getActiveCreditAccountOrRevert();
    }

    /// @dev Ensures that token is registered as collateral in the credit manager and returns its mask
    function _getMaskOrRevert(address token) internal view returns (uint256 tokenMask) {
        tokenMask = ICreditManagerV3(creditManager).getTokenMaskOrRevert(token);
    }

    /// @dev Approves target contract to spend given token from the active credit account
    ///      Reverts if active credit account is not set or token is not registered as collateral
    /// @param token Token to approve
    /// @param amount Amount to approve
    function _approveToken(address token, uint256 amount) internal {
        ICreditManagerV3(creditManager).approveCreditAccount(token, amount);
    }

    /// @dev Executes an external call from the active credit account to the target contract
    ///      Reverts if active credit account is not set
    /// @param callData Data to call the target contract with
    /// @return result Call result
    function _execute(bytes memory callData) internal returns (bytes memory result) {
        return ICreditManagerV3(creditManager).execute(callData);
    }

    /// @dev Executes a swap operation with maximum input token approval, and revokes approval after the call
    ///      Reverts if active credit account is not set or any of passed tokens is not registered as collateral
    /// @param tokenIn Input token that credit account spends in the call
    /// @param callData Data to call the target contract with
    /// @return result Call result
    /// @custom:expects Credit manager reverts when trying to approve non-collateral token
    function _executeSwapSafeApprove(address tokenIn, bytes memory callData) internal returns (bytes memory result) {
        _approveToken(tokenIn, type(uint256).max);
        result = _execute(callData);
        _approveToken(tokenIn, 1);
    }
}
