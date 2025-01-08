// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {FarmingTrait} from "./traits/FarmingTrait.sol";
import {WstETHTrait} from "./traits/WstETHTrait.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title wstETH farming zapper
/// @notice Zapper that allows to deposit stETH directly into a wstETH pool and stake shares in 1inch farming contract
contract WstETHFarmingZapper is WstETHTrait, FarmingTrait {
    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "ZAPPER::WSTETH_FARMING";

    constructor(address pool, address farmingPool) ZapperBase(pool) WstETHTrait() FarmingTrait(farmingPool) {}
}
