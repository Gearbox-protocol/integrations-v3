// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {FarmingMixin} from "./mixins/FarmingMixin.sol";
import {WstETHMixin} from "./mixins/WstETHMixin.sol";
import {ZapperBase} from "./ZapperBase.sol";

contract WstETHFarmingZapper is WstETHMixin, FarmingMixin {
    constructor(address pool, address farmingPool) ZapperBase(pool) WstETHMixin() FarmingMixin(farmingPool) {}
}
