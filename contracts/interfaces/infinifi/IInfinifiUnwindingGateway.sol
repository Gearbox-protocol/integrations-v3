// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

struct UserUnwindingData {
    uint256 shares;
    uint32 unwindingEpochs;
    uint256 unwindingTimestamp;
    uint256 unclaimedAssets;
    bool isWithdrawn;
}

interface IInfinifiUnwindingGatewayExceptions {
    /// @notice Thrown when a user attempts a second unwinding in the same block
    error MoreThanOneUnwindingPerBlockException();

    /// @notice Thrown when a user attempts to start unwinding while already unwinding
    error UserAlreadyUnwindingException();

    /// @notice Thrown when a user attempts to withdraw while not unwinding
    error UserNotUnwindingException();

    /// @notice Thrown when a user attempts to withdraw an unwinding that is not claimable
    error UnwindingNotClaimableException();

    /// @notice Thrown when a user attempts to withdraw an unwinding for more assets than are pending
    error InsufficientPendingAssetsException();
}

interface IInfinifiUnwindingGateway is IVersion, IInfinifiUnwindingGatewayExceptions {
    function iUSD() external view returns (address);

    function startUnwinding(uint256 shares, uint32 unwindingEpochs) external;

    function withdraw(uint256 unwindingTimestamp) external;

    function getPendingAssets(address user) external view returns (uint256);
}
