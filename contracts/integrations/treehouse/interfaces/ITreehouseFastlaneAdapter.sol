// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

interface ITreehouseFastlaneAdapter is IAdapter {
    function tAsset() external view returns (address);

    function vaultUnderlying() external view returns (address);

    function redeemAndFinalize(uint256 shares) external returns (bool);

    function redeemAndFinalizeDiff(uint256 leftoverShares) external returns (bool);
}
