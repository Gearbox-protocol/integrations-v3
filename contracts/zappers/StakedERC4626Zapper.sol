// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {DepositTrait} from "./traits/DepositTrait.sol";
import {StakedERC4626Trait} from "./traits/StakedERC4626Trait.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title Staked ERC-4626 zapper
/// @notice Zapper that allows to move funds from a staked ERC-4626 vault to a Gearbox pool in one call
contract StakedERC4626Zapper is StakedERC4626Trait, DepositTrait {
    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "ZAPPER::STAKED_ERC4626";

    constructor(address pool_, address farmingPool_) ZapperBase(pool_) StakedERC4626Trait(farmingPool_) {}

    function serialize() public view override returns (bytes memory) {
        return abi.encode(farmingPool, vault);
    }
}
