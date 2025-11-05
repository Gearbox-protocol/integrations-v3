// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

/// @title Mellow Flexible Deposit Queue Gateway interface
/// @notice Interface for the gateway to interact with Mellow's Flexible Vaults Deposit Queue
interface IMellowFlexibleDepositGateway is IVersion {
    function vaultToken() external view returns (address);
    function asset() external view returns (address);
    function getPendingAssets(address account) external view returns (uint256);
    function getClaimableShares(address account) external view returns (uint256);

    function deposit(uint256 assets, address referral, bytes32[] calldata) external;
    function cancelDepositRequest() external;
    function claim(uint256 amount) external;
}
