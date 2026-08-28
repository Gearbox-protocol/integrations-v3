// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

interface IBalancerV3WrapperAdapter is IAdapter {
    function balancerPoolToken() external view returns (address);

    function mint(uint256 amount) external returns (bool useSafePrices);

    function mintDiff(uint256 leftoverAmount) external returns (bool useSafePrices);

    function burn(uint256 amount) external returns (bool useSafePrices);

    function burnDiff(uint256 leftoverAmount) external returns (bool useSafePrices);
}
