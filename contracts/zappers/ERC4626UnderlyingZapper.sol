// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.23;

import {DepositTrait} from "./traits/DepositTrait.sol";
import {ERC4626UnderlyingTrait} from "./traits/ERC4626UnderlyingTrait.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title  ERC-4626 underlying zapper
/// @author Gearbox Foundation
/// @notice Zapper for one-click deposits and withdrawals of an ERC-4626 vault's asset
///         into and from a Gearbox pool with this vault's shares as underlying token
contract ERC4626UnderlyingZapper is ERC4626UnderlyingTrait, DepositTrait {
    bytes32 public constant override contractType = "ZAPPER::ERC4626_UNDERLYING";
    uint256 public constant override version = 3_10;

    constructor(address pool_) ZapperBase(pool_) {}
}
