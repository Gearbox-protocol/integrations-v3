// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {DepositTrait} from "./traits/DepositTrait.sol";
import {WETHTrait} from "./traits/WETHTrait.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title WETH deposit zapper
/// @notice Zapper that allows to deposit ETH directly into a WETH pool
contract WETHDepositZapper is WETHTrait, DepositTrait {
    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "ZAPPER::WETH_DEPOSIT";

    constructor(address pool) ZapperBase(pool) {}
}
