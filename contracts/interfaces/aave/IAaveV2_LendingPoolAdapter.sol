// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

/// @title Aave V2 LendingPool adapter interface
interface IAaveV2_LendingPoolAdapter is IAdapter {
    function deposit(address asset, uint256 amount, address, uint16)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function depositDiff(address asset, uint256 leftoverAmount)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdraw(address asset, uint256 amount, address)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdrawDiff(address asset, uint256 leftoverAmount)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);
}
