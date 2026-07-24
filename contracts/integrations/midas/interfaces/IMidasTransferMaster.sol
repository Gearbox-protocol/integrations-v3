// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

interface IMidasTransferMaster is IVersion {
    /// @notice The account currently allowed to transfer redeemers, or address(0) if none
    function transferableRedeemerOwner() external view returns (address);

    /// @notice Whether the given redeemer owner is currently allowed to transfer redeemers
    function isTransferAllowed(address redeemerOwner) external view returns (bool);
}
