// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {DepositMixin} from "./mixins/DepositMixin.sol";
import {WATokenMixin} from "./mixins/WATokenMixin.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title waToken deposit zapper
/// @notice Zapper that allows to deposit aToken directly into a waToken pool
contract WATokenDepositZapper is WATokenMixin, DepositMixin {
    constructor(address pool) ZapperBase(pool) WATokenMixin() {}
}
