// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {DepositMixin} from "./mixins/DepositMixin.sol";
import {WstETHMixin} from "./mixins/WstETHMixin.sol";
import {ZapperBase} from "./ZapperBase.sol";

contract WstETHDepositZapper is WstETHMixin, DepositMixin {
    constructor(address pool) ZapperBase(pool) WstETHMixin() {}
}
