// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

interface IYearnV2Adapter is IAdapter {
    /// @dev Address of the token that is deposited into the vault
    function token() external view returns (address);

    function deposit() external;

    function deposit(uint256 amount) external;

    function deposit(uint256 amount, address) external;

    function withdraw() external;

    function withdraw(uint256 maxShares) external;

    function withdraw(uint256 maxShares, address) external;

    function withdraw(uint256 maxShares, address, uint256 maxLoss) external;
}
