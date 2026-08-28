// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

bytes32 constant CREDIT_ACCOUNT_TYPE = "CREDIT_ACCOUNT";

/// @title Credit account checker interface
/// @notice Shared eligibility surface for gateways that only accept credit accounts from a given market configurator
interface ICAChecker {
    /// @dev Thrown when an account that is not eligible to interact with the gateway attempts to interact with it
    error CreditAccountNotEligibleException();

    /// @dev Thrown when the gateway is configured without an allowed market configurator
    error MarketConfiguratorNotSetException();

    /// @notice Address of the market configurator of credit accounts that are allowed to interact with the gateway
    function allowedMarketConfigurator() external view returns (address);

    /// @notice Whether `account` is eligible to interact with the gateway
    function isAccountEligible(address account) external view returns (bool);
}
