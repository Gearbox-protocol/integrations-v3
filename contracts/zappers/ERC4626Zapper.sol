// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {DepositTrait} from "./traits/DepositTrait.sol";
import {ERC4626Trait} from "./traits/ERC4626Trait.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title ERC-4626 zapper
/// @notice Zapper that allows to move funds from an ERC-4626 vault to a Gearbox pool in one call
contract ERC4626Zapper is ERC4626Trait, DepositTrait {
    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "ZAPPER::ERC4626";

    constructor(address pool_, address vault_) ZapperBase(pool_) ERC4626Trait(vault_) {}

    function serialize() public view override returns (bytes memory) {
        return abi.encode(vault);
    }
}
