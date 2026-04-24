// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {PriceUpdate} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeedStore.sol";

interface ISecuritizeLiquidator is IVersion {
    error NotValidGatewayException();
    error CreditAccountNotLiquidatableException();
    error AccountHasSufficientLiquidityException();

    function liquidatePendingRedemption(
        address creditAccount,
        address redemptionGateway,
        PriceUpdate[] memory priceUpdates
    ) external;
}
