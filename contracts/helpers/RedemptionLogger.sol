// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IRedemptionLogger} from "../interfaces/IRedemptionLogger.sol";

/// @title Redemption Logger
/// @notice Stores and emits redemption events for off-chain indexing
contract RedemptionLogger is Ownable, IRedemptionLogger {
    bytes32 public constant override contractType = "HELPER::REDEMPTION_LOGGER";
    uint256 public constant override version = 3_10;

    mapping(address => RedemptionLog) internal _redemptionLogs;
    mapping(address => bool) public override allowedGateways;

    constructor(address _owner) Ownable() {
        _transferOwnership(_owner);
    }

    /// @inheritdoc IRedemptionLogger
    function redemptionLogs(address redeemer) external view override returns (RedemptionLog memory) {
        return _redemptionLogs[redeemer];
    }

    /// @inheritdoc IRedemptionLogger
    function setGatewayAllowed(address gateway, bool allowed) external override onlyOwner {
        allowedGateways[gateway] = allowed;
    }

    /// @inheritdoc IRedemptionLogger
    function logRedemption(address creditAccount, address redeemer, bytes calldata extraData) external override {
        if (!allowedGateways[msg.sender]) revert GatewayNotAllowedException();

        _redemptionLogs[redeemer] =
            RedemptionLog({creditAccount: creditAccount, redeemer: redeemer, extraData: extraData});
        emit RedemptionLogged(creditAccount, redeemer, extraData);
    }
}
