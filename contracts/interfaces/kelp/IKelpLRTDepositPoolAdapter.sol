// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

/// @title Kelp LRTDepositPool adapter interface
interface IKelpLRTDepositPoolAdapter is IAdapter {
    /// @notice Emitted when the allowed status of an asset is set
    event SetAssetStatus(address asset, bool allowed);

    /// @notice Emitted when attempting to deposit an asset that is not allowed in the adapter
    error AssetNotAllowedException(address asset);

    /// @notice Emitted when the array lengths do not match
    error IncorrectArrayLengthException();

    function referralId() external view returns (string memory);

    function depositAsset(address asset, uint256 amount, uint256 minRSETHAmountExpected, string calldata referralId)
        external
        returns (bool);

    function depositAssetDiff(address asset, uint256 leftoverAmount, uint256 minRateRAY) external returns (bool);

    function setAssetStatusBatch(address[] calldata assets, bool[] calldata allowed) external;

    function allowedAssets() external view returns (address[] memory);
}
