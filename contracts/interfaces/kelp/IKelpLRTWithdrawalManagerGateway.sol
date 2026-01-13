// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

/// @title Kelp LRT Withdrawal Manager Gateway interface
/// @notice Interface for the gateway to interact with Mellow's Flexible Vaults Deposit Queue
interface IKelpLRTWithdrawalManagerGateway is IVersion {
    function rsETH() external view returns (address);
    function withdrawalManager() external view returns (address);
    function accountToWithdrawer(address account) external view returns (address payable);
    function initiateWithdrawal(address asset, uint256 rsETHUnstaked, string calldata referralId) external;
    function completeWithdrawal(address asset, uint256 amount, string calldata referralId) external;
    function getPendingAssetAmount(address account, address asset) external view returns (uint256);
    function getClaimableAssetAmount(address account, address asset) external view returns (uint256);
    function getPendingAndClaimableAssetAmounts(address account, address asset)
        external
        view
        returns (uint256 pendingAssets, uint256 claimableAssets);
}
