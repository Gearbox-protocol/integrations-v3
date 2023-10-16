// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {DepositMixin} from "./mixins/DepositMixin.sol";
import {WETHMixin} from "./mixins/WETHMixin.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title WETH deposit zapper
/// @notice Zapper that allows to deposit ETH directly into a WETH pool
contract WETHDepositZapper is WETHMixin, DepositMixin {
    constructor(address pool) ZapperBase(pool) {}
}
