// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

interface IMellowWrapperGateway is IVersion {
    function deposit(address depositToken, uint256 amount, address vault, address receiver, address referral)
        external
        returns (uint256 shares);
}
