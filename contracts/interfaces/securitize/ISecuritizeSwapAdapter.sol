// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

/// @title Securitize Swap adapter interface
interface ISecuritizeSwapAdapter is IAdapter {
    function dsToken() external view returns (address);

    function stableCoinToken() external view returns (address);

    function buy(uint256 dsTokenAmount, uint256 maxStableCoinAmount) external returns (bool);

    function buyExactIn(uint256 stableCoinAmount) external returns (bool);

    function buyExactInDiff(uint256 leftoverAmount) external returns (bool);
}
