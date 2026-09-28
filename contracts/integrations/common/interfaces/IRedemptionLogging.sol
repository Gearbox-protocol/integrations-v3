// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

/// @title Redemption logging interface
/// @notice Shared surface for gateways that report redemptions to a redemption logger
interface IRedemptionLogging {
    /// @notice Address of the redemption logger contract
    function redemptionLogger() external view returns (address);
}
