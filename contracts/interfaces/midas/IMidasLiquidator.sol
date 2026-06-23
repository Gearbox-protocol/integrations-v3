// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {PriceUpdate} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeedStore.sol";

import {IMidasTransferMaster} from "./IMidasTransferMaster.sol";

interface IMidasLiquidator is IMidasTransferMaster {
    /// @dev Thrown when the passed gateway is not a valid Midas gateway for the liquidated account
    error NotValidGatewayException();

    function liquidateWithRedeemerTransfers(
        address creditAccount,
        address gateway,
        MultiCall[] calldata calls,
        bytes memory lossPolicyData
    ) external;
}
