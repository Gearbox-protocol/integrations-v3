// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IPhantomTokenAdapter} from "../IPhantomTokenAdapter.sol";

struct LockedTokenStatus {
    address lockedToken;
    uint32 unwindingEpochs;
    bool allowed;
}

interface IInfinifiGatewayEvents {
    event SetLockedTokenStatus(address lockedToken, uint32 unwindingEpochs, bool allowed);
}

interface IInfinifiGatewayExceptions {
    /// @notice Thrown when the passed unwinding epochs for the locked token do not match actual unwinding epochs in Infinifi
    error LockedTokenUnwindingEpochsMismatchException();

    /// @notice Thrown when the locked token is not allowed
    error LockedTokenNotAllowedException();
}

interface IInfinifiUnwindingGatewayAdapter is
    IPhantomTokenAdapter,
    IInfinifiGatewayExceptions,
    IInfinifiGatewayEvents
{
    function lockedTokenToUnwindingEpoch(address lockedToken) external view returns (uint32);

    function startUnwinding(uint256 shares, uint32 unwindingEpochs) external;

    function withdraw(uint256 amount) external;

    function getAllowedLockedTokens() external view returns (address[] memory);

    function setLockedTokenBatchStatus(LockedTokenStatus[] calldata lockedTokens) external;
}
