// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IPhantomTokenAdapter} from "../IPhantomTokenAdapter.sol";

/// @title Mellow Flexible Vault Deposit Queue adapter interface
/// @notice Interface for the adapter to interact with Mellow's Flexible Vaults Deposit Queue
interface IMellowDepositQueueAdapter is IPhantomTokenAdapter {
    error InvalidDepositQueueGatewayException();

    function asset() external view returns (address);

    function phantomToken() external view returns (address);

    function referral() external view returns (address);

    function deposit(uint256 assets, address, bytes32[] calldata) external returns (bool);

    function depositDiff(uint256 leftoverAmount) external returns (bool);

    function cancelDepositRequest() external returns (bool);

    function claim(uint256 amount) external returns (bool);
}
