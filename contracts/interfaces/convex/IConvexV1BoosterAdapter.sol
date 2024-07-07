// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

/// @title Convex V1 Booster adapter interface
interface IConvexV1BoosterAdapter is IAdapter {
    /// @notice Thrown when attempting to make a deposit into a pool with unknown pid
    error UnsupportedPidException();

    /// @notice Emitted when a new supported pid is added to booster adapter
    event AddSupportedPid(uint256 indexed pid);

    function deposit(uint256 _pid, uint256, bool _stake) external returns (bool useSafePrices);

    function depositDiff(uint256 leftoverAmount, uint256 _pid, bool _stake) external returns (bool useSafePrices);

    function withdraw(uint256 _pid, uint256) external returns (bool useSafePrices);

    function withdrawDiff(uint256 leftoverAmount, uint256 _pid) external returns (bool useSafePrices);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function pidToPhantomToken(uint256) external view returns (address);
    function pidToCurveToken(uint256) external view returns (address);
    function pidToConvexToken(uint256) external view returns (address);

    function updateSupportedPids() external;
}
