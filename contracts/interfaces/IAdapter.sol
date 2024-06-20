// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v2/contracts/interfaces/IVersion.sol";

/// @title Adapter interface
interface IAdapter is IVersion {
    function adapterType() external view returns (uint256);

    function creditManager() external view returns (address);

    function targetContract() external view returns (address);
}
