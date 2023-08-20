// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";

/// @title Yearn V2 Vault adapter interface
interface IYearnV2Adapter is IAdapter {
    function token() external view returns (address);

    function tokenMask() external view returns (uint256);

    function yTokenMask() external view returns (uint256);

    function deposit() external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function deposit(uint256 amount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function deposit(uint256 amount, address) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdraw() external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdraw(uint256 maxShares) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdraw(uint256 maxShares, address) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdraw(uint256 maxShares, address, uint256 maxLoss)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);
}
