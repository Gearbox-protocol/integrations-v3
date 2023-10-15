// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {FarmingMixin} from "./mixins/FarmingMixin.sol";
import {WETHMixin} from "./mixins/WETHMixin.sol";
import {ZapperBase} from "./ZapperBase.sol";

contract WETHFarmingZapper is WETHMixin, FarmingMixin {
    constructor(address pool, address farmingPool) ZapperBase(pool) FarmingMixin(farmingPool) {}
}
