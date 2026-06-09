// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

interface IMidasRWAGreenlisterAdapter is IAdapter {
    /// @notice Thrown when the target contract is not a Midas RWA greenlister
    error InvalidGreenlisterException();

    /// @notice Thrown when the greenlister target contract is not a GREENLISTED_ROLE admin
    error NotGreenlistOperatorException();

    /// @notice Grants Midas greenlist status to the active credit account
    function grantGreenlist() external returns (bool);
}
