// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20Trait} from "./traits/ERC20Trait.sol";
import {FarmingTrait} from "./traits/FarmingTrait.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title ERC20 farming zapper
/// @notice Zapper that allows to deposit an ERC20 token into a pool and stake shares in 1inch farming contract
contract ERC20FarmingZapper is ERC20Trait, FarmingTrait {
    constructor(address pool, address farmingPool) ZapperBase(pool) FarmingTrait(farmingPool) {}
}
