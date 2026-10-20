// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

interface ITreehouseRouterAdapter is IAdapter {
    event SetAssetStatus(address indexed asset, bool allowed);

    error InvalidAssetException();

    function deposit(address token, uint256 amount) external returns (bool);

    function depositDiff(address token, uint256 leftoverAmount) external returns (bool);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function isAssetAllowed(address asset) external view returns (bool);

    function allowedAssets() external view returns (address[] memory);

    function setAssetStatusBatch(address[] calldata assets, bool[] calldata allowed) external;
}
