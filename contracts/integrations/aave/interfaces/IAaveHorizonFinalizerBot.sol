// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IBot} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IBot.sol";
import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";

/// @title Aave Horizon Finalizer Bot interface
interface IAaveHorizonFinalizerBot is IBot {
    /// @dev Thrown when claimCall emptiness does not match the phantom token presence
    error InvalidClaimPhantomPairException();

    /// @dev Thrown when a required adapter is not configured on the credit manager
    error AdapterNotFoundException();

    /// @notice Horizon Pool address
    function pool() external view returns (address);

    /// @notice Horizon Bridge address
    function bridge() external view returns (address);

    /// @notice Finalizes opening a Horizon position after RWA is available on the credit account
    /// @param creditAccount Credit account to operate on
    /// @param rwaToken Underlying RWA to supply into Horizon
    /// @param claimCall Optional delayed-deposit claim call; empty if unused
    /// @param depositPhantomToken Phantom token to zero quota for; non-zero iff `claimCall` is non-empty
    function finalizeOpen(
        address creditAccount,
        address rwaToken,
        MultiCall calldata claimCall,
        address depositPhantomToken
    ) external;

    /// @notice Finalizes closing after redemption: optional claim, zero quota, repay debt, withdraw leftover underlying
    /// @param creditAccount Credit account to operate on
    /// @param claimCall Optional redemption claim call; empty if unused
    /// @param withdrawPhantomToken Phantom token to zero quota for; non-zero iff `claimCall` is non-empty
    function finalizeClose(address creditAccount, MultiCall calldata claimCall, address withdrawPhantomToken) external;
}
