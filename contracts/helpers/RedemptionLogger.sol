// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IRedemptionLogger} from "../interfaces/IRedemptionLogger.sol";

/// @title Redemption Logger
/// @notice Stores and emits redemption events for off-chain indexing
contract RedemptionLogger is IRedemptionLogger {
    mapping(address => RedemptionLog) internal _redemptionLogs;

    /// @inheritdoc IRedemptionLogger
    function redemptionLogs(address redeemer) external view override returns (RedemptionLog memory) {
        return _redemptionLogs[redeemer];
    }

    /// @inheritdoc IRedemptionLogger
    function logRedemption(address creditAccount, address redeemer, bytes calldata extraData) external override {
        _redemptionLogs[redeemer] =
            RedemptionLog({creditAccount: creditAccount, redeemer: redeemer, extraData: extraData});
        emit RedemptionLogged(creditAccount, redeemer, extraData);
    }
}
