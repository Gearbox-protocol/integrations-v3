// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC4626Adapter} from "../erc4626/IERC4626Adapter.sol";
import {IPhantomTokenAdapter} from "../IPhantomTokenAdapter.sol";

/// @title Mellow ERC4626 Vault adapter interface
/// @notice Interface for the adapter to interact with Mellow's ERC4626 vaults
interface IMellow4626VaultAdapter is IERC4626Adapter, IPhantomTokenAdapter {
    /// @notice Error thrown when the actually claimed amount is less than the requested amount
    error InsufficientClaimedException();

    /// @notice Address of the staked phantom token
    function stakedPhantomToken() external view returns (address);

    /// @notice Claims mature withdrawals from the vault
    /// @param account Account to claim for (ignored, always credit account)
    /// @param recipient Recipient of the claim (ignored, always credit account)
    /// @param maxAmount Maximum amount to claim
    /// @return Whether safe prices should be used
    function claim(address account, address recipient, uint256 maxAmount) external returns (bool);
}
