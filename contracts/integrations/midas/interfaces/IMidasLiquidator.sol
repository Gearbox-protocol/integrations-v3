// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";

import {IMidasTransferMaster} from "./IMidasTransferMaster.sol";

/// @title Midas liquidator interface
/// @notice Liquidation entry point that unlocks redeemer transfers for the duration of the liquidation
interface IMidasLiquidator is IMidasTransferMaster {
    /// @dev Thrown when the passed gateway is not a valid Midas gateway for the liquidated account
    error NotValidGatewayException();

    /// @notice Liquidates a credit account, allowing the liquidator's calls to transfer its redeemers
    /// @param creditAccount Credit account to liquidate
    /// @param gateway Midas gateway whose redeemers are transferred during the liquidation
    /// @param calls Liquidator-supplied multicall forwarded to the credit facade
    /// @param lossPolicyData Loss policy data forwarded to the credit facade
    function liquidateWithRedeemerTransfers(
        address creditAccount,
        address gateway,
        MultiCall[] calldata calls,
        bytes memory lossPolicyData
    ) external;
}
