// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

interface IERC4626Adapter is IAdapter {
    function asset() external view returns (address);

    function referral() external view returns (uint16);

    function deposit(uint256 assets, address) external returns (bool useSafePrices);

    function depositDiff(uint256 leftoverAmount) external returns (bool useSafePrices);

    function mint(uint256 shares, address) external returns (bool useSafePrices);

    function withdraw(uint256 assets, address, address) external returns (bool useSafePrices);

    function redeem(uint256 shares, address, address) external returns (bool useSafePrices);

    function redeemDiff(uint256 leftoverAmount) external returns (bool useSafePrices);
}
