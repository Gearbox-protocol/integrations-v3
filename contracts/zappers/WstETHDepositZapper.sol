// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {DepositTrait} from "./traits/DepositTrait.sol";
import {WstETHTrait} from "./traits/WstETHTrait.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title wstETH deposit zapper
/// @notice Zapper that allows to deposit stETH directly into a wstETH pool
contract WstETHDepositZapper is WstETHTrait, DepositTrait {
    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "ZAP_WSTETH_DEPOSIT";

    constructor(address pool) ZapperBase(pool) WstETHTrait() {}
}
