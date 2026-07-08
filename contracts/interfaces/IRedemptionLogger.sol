// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

/// @title Redemption Logger interface
interface IRedemptionLogger {
    /// @dev Thrown when `logRedemption` is called by a non-allowed gateway
    error GatewayNotAllowedException();

    /// @notice Logged redemption data
    /// @param creditAccount Credit account address
    /// @param redeemer Redeemer contract address
    /// @param extraData Additional redemption data
    struct RedemptionLog {
        address creditAccount;
        address redeemer;
        bytes extraData;
    }

    /// @notice Emitted when a redemption is logged
    /// @param creditAccount Credit account address
    /// @param redeemer Redeemer contract address
    /// @param extraData Additional redemption data (stored in log data, not hashed)
    event RedemptionLogged(address indexed creditAccount, address indexed redeemer, bytes extraData);

    /// @notice Returns logged redemption data for a redeemer
    /// @param redeemer Redeemer contract address
    function redemptionLogs(address redeemer) external view returns (RedemptionLog memory);

    /// @notice Returns whether a gateway is allowed to log redemptions
    /// @param gateway Gateway address
    function allowedGateways(address gateway) external view returns (bool);

    /// @notice Sets whether a gateway is allowed to log redemptions
    /// @param gateway Gateway address
    /// @param allowed Whether the gateway is allowed to log redemptions
    /// @dev Can only be called by the owner
    function setGatewayAllowed(address gateway, bool allowed) external;

    /// @notice Logs a redemption event
    /// @param creditAccount Credit account address
    /// @param redeemer Redeemer contract address
    /// @param extraData Additional redemption data
    function logRedemption(address creditAccount, address redeemer, bytes calldata extraData) external;
}
