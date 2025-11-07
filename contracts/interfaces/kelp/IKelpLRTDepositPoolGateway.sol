// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

/// @title Kelp LRTDepositPool Gateway interface
/// @notice Interface for the gateway to interact with Kelp's LRTDepositPool
interface IKelpLRTDepositPoolGateway is IVersion {
    function rsETH() external view returns (address);

    function depositAsset(address asset, uint256 amount, uint256 minRSETHAmountExpected, string calldata referralId)
        external;
}
