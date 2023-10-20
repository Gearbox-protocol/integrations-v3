// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {FarmingTrait} from "./traits/FarmingTrait.sol";
import {UnderlyingTrait} from "./traits/UnderlyingTrait.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title Underlying farming zapper
/// @notice Zapper that allows to deposit underlying token into a pool and stake shares in 1inch farming contract
contract UnderlyingFarmingZapper is UnderlyingTrait, FarmingTrait {
    constructor(address pool, address farmingPool) ZapperBase(pool) FarmingTrait(farmingPool) {}
}
