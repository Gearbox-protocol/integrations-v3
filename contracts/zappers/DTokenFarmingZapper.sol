// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {FarmingTrait} from "./traits/FarmingTrait.sol";
import {DTokenTrait} from "./traits/DTokenTrait.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title Diesel token farming zapper
/// @notice Zapper that allows to migrate liquidity from older to newer pools and stake shares in 1inch farming contract
contract DTokenFarmingZapper is DTokenTrait, FarmingTrait {
    constructor(address newPool, address oldPool, address farmingPool)
        ZapperBase(newPool)
        DTokenTrait(oldPool)
        FarmingTrait(farmingPool)
    {}
}
