// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC4626Adapter} from "../erc4626/IERC4626Adapter.sol";
import {IPhantomTokenAdapter} from "../IPhantomTokenAdapter.sol";

/// @title Mellow ERC4626 Vault adapter interface
/// @notice Interface for the adapter to interact with Mellow's ERC4626 vaults
interface IMellow4626VaultAdapter is IERC4626Adapter {
    /// @notice Thrown when attempting to deposit into a Mellow vault where direct deposits are not allowed
    error DepositsWhitelistedException();

    /// @notice Thrown when the multivault in the staked phantom token does not match the one in the adapter
    error InvalidMultivaultException();
}
