// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

/// @title FluidDex adapter interface
interface IFluidDexAdapter is IAdapter {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function swapIn(bool swap0to1, uint256 amountIn, uint256 amountOutMin, address to) external returns (bool);

    function swapInDiff(bool swap0to1, uint256 leftoverAmount, uint256 rateMinRAY) external returns (bool);
}
