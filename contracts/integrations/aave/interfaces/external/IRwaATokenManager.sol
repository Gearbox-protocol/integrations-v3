// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

/// @title RwaATokenManager interface (minimal)
/// @notice Subset of Aave Horizon's RWA aToken manager used by `AaveHorizonBridge`
interface IRwaATokenManager {
    /// @notice Transfers RWA aTokens between two addresses via the aToken's `authorizedTransfer`
    /// @dev Caller must hold the per-aToken authorized transfer role
    /// @param aToken The RWA aToken to transfer
    /// @param from The address to transfer from
    /// @param to The address to transfer to
    /// @param amount The amount of aTokens to transfer
    /// @return Whether the transfer succeeded
    function transferRwaAToken(address aToken, address from, address to, uint256 amount) external returns (bool);
}
