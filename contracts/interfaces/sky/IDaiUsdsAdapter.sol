// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

/// @title DaiUsds adapter interface
interface IDaiUsdsAdapter is IAdapter {
    function dai() external view returns (address);

    function usds() external view returns (address);

    function daiToUsds(address, uint256) external returns (bool);

    function usdsToDai(address, uint256) external returns (bool);

    function daiToUsdsDiff(uint256) external returns (bool);

    function usdsToDaiDiff(uint256) external returns (bool);
}
