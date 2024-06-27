// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IAdapter} from "../../interfaces/IAdapter.sol";

/// @title wstETH adapter interface
interface IwstETHV1Adapter is IAdapter {
    function stETH() external view returns (address);

    function wrap(uint256 amount) external returns (bool useSafePrices);

    function wrapDiff(uint256 leftoverAmount) external returns (bool useSafePrices);

    function unwrap(uint256 amount) external returns (bool useSafePrices);

    function unwrapDiff(uint256 leftoverAmount) external returns (bool useSafePrices);
}
