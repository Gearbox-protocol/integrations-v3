// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {DepositTrait} from "./traits/DepositTrait.sol";
import {WATokenTrait} from "./traits/WATokenTrait.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title waToken deposit zapper
/// @notice Zapper that allows to deposit aToken directly into a waToken pool
contract WATokenDepositZapper is WATokenTrait, DepositTrait {
    constructor(address pool) ZapperBase(pool) WATokenTrait() {}
}
