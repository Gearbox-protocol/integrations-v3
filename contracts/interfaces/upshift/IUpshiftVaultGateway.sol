// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

interface IUpshiftVaultGateway is IVersion {
    function upshiftVault() external view returns (address);
    function pendingAssetsOf(address account) external view returns (uint256);
    function requestRedeem(uint256 shares) external;
    function claim(uint256 amount) external;
}
