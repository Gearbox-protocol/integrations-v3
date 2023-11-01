// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";

/// @title wstETH adapter interface
interface IwstETHV1Adapter is IAdapter {
    function stETH() external view returns (address);

    function stETHTokenMask() external view returns (uint256);

    function wstETHTokenMask() external view returns (uint256);

    function wrap(uint256 amount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function wrapDiff(uint256 leftoverAmount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function unwrap(uint256 amount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function unwrapDiff(uint256 leftoverAmount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);
}
