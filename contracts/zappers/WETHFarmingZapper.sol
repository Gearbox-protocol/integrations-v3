// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {FarmingTrait} from "./traits/FarmingTrait.sol";
import {WETHTrait} from "./traits/WETHTrait.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title WETH farming zapper
/// @notice Zapper that allows to deposit ETH directly into a WETH pool and stake shares in 1inch farming contract
contract WETHFarmingZapper is WETHTrait, FarmingTrait {
    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "ZAPPER::WETH_FARMING";

    constructor(address pool_, address farmingPool) ZapperBase(pool_) FarmingTrait(farmingPool) {}
}
