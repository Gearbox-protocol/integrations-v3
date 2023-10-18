// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {DepositTrait} from "./traits/DepositTrait.sol";
import {ERC20Trait} from "./traits/ERC20Trait.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title ERC20 deposit zapper
/// @notice Zapper that allows to deposit an ERC20 token into a pool in one call using permit
contract ERC20DepositZapper is ERC20Trait, DepositTrait {
    constructor(address pool) ZapperBase(pool) {}
}
