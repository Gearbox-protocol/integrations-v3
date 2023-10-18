// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {FarmingTrait} from "./traits/FarmingTrait.sol";
import {WATokenTrait} from "./traits/WATokenTrait.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title waToken farming zapper
/// @notice Zapper that allows to deposit aToken directly into a waToken pool and stake shares in 1inch farming contract
contract WATokenFarmingZapper is WATokenTrait, FarmingTrait {
    constructor(address pool, address farmingPool) ZapperBase(pool) WATokenTrait() FarmingTrait(farmingPool) {}
}
