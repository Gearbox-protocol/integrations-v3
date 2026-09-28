// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAddressProvider} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAddressProvider.sol";

import {IRedemptionLogging} from "./interfaces/IRedemptionLogging.sol";
import {IRedemptionLogger, AP_REDEMPTION_LOGGER} from "./interfaces/IRedemptionLogger.sol";

/// @title Redemption logging trait
/// @notice Shared redemption-logger wiring for gateways that report redemption initiations
abstract contract RedemptionLoggingTrait is IRedemptionLogging {
    /// @notice Address of the redemption logger contract
    address public immutable override redemptionLogger;

    /// @notice Constructor
    /// @param addressProvider Address of the Gearbox AddressProvider
    constructor(address addressProvider) {
        redemptionLogger = IAddressProvider(addressProvider).getAddressOrRevert(AP_REDEMPTION_LOGGER, 3_10);
    }

    /// @dev Logs a redemption initiation
    function _logRedemption(address creditAccount, address redeemer, bytes calldata extraData) internal {
        IRedemptionLogger(redemptionLogger).logRedemption(creditAccount, redeemer, extraData);
    }
}
