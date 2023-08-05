// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {AdapterType} from "@gearbox-protocol/sdk/contracts/AdapterType.sol";

interface IAdapter {
    /// @notice Credit Manager the adapter is connected to
    function creditManager() external view returns (address);

    /// @notice Address of the contract the adapter is interacting with
    function targetContract() external view returns (address);

    /// @notice Address provider
    function addressProvider() external view returns (address);

    /// @notice Adapter type
    function _gearboxAdapterType() external pure returns (AdapterType);

    /// @notice Adapter version
    function _gearboxAdapterVersion() external pure returns (uint16);
}
