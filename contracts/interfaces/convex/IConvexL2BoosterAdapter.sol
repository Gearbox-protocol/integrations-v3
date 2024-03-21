// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";

/// @title Convex L2 Booster adapter interface
interface IConvexL2BoosterAdapter is IAdapter {
    function deposit(uint256 _pid, uint256) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function depositDiff(uint256 _pid, uint256 leftoverAmount)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);
}
