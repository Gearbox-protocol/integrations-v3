// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IAdapter} from "../IAdapter.sol";

/// @title Yearn V2 Vault adapter interface
interface IYearnV2Adapter is IAdapter {
    function token() external view returns (address);

    function depositDiff(uint256 leftoverAmount) external returns (bool useSafePrices);

    function deposit(uint256 amount) external returns (bool useSafePrices);

    function deposit(uint256 amount, address) external returns (bool useSafePrices);

    function withdrawDiff(uint256 leftoverAmount) external returns (bool useSafePrices);

    function withdraw(uint256 maxShares) external returns (bool useSafePrices);

    function withdraw(uint256 maxShares, address) external returns (bool useSafePrices);

    function withdraw(uint256 maxShares, address, uint256 maxLoss) external returns (bool useSafePrices);
}
