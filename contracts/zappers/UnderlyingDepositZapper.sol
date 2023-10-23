// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {DepositTrait} from "./traits/DepositTrait.sol";
import {UnderlyingTrait} from "./traits/UnderlyingTrait.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title Underlying deposit zapper
/// @notice Zapper that allows to deposit underlying token into a pool in one call using permit
contract UnderlyingDepositZapper is UnderlyingTrait, DepositTrait {
    constructor(address pool) ZapperBase(pool) {}
}
