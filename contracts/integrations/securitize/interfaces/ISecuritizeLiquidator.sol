// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {PriceUpdate} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeedStore.sol";

import {ISecuritizeGatewayTransferMaster} from "./ISecuritizeGatewayTransferMaster.sol";

interface ISecuritizeLiquidator is ISecuritizeGatewayTransferMaster {
    error NotValidGatewayException();
    error UnknownCreditAccountException();
    error AccountHasSufficientLiquidityException();
    error StableCoinIsNotConvertibleException();

    function liquidatePendingRedemption(
        address creditAccount,
        address redemptionGateway,
        PriceUpdate[] memory priceUpdates,
        bytes memory lossPolicyData
    ) external;
}
