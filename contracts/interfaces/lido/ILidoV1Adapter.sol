// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

/// @title Lido V1 adapter interface
interface ILidoV1Adapter is IAdapter {
    function weth() external view returns (address);

    function stETH() external view returns (address);

    function treasury() external view returns (address);

    function submit(uint256 amount) external returns (bool useSafePrices);

    function submitDiff(uint256 leftoverAmount) external returns (bool useSafePrices);
}
