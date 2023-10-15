// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20Mixin} from "./mixins/ERC20Mixin.sol";
import {FarmingMixin} from "./mixins/FarmingMixin.sol";
import {ZapperBase} from "./ZapperBase.sol";

contract ERC20FarmingZapper is ERC20Mixin, FarmingMixin {
    constructor(address pool, address farmingPool) ZapperBase(pool) FarmingMixin(farmingPool) {}
}
