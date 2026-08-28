// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {IPhantomTokenWithdrawer} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

/// @title Phantom token adapter interface
interface IPhantomTokenAdapter is IAdapter, IPhantomTokenWithdrawer {
    /// @notice Thrown when attempting to deposit or withdraw a token that is not the staked phantom token
    error IncorrectStakedPhantomTokenException();

    /// @notice Provides a generic interface for deposits, which is useful for external integrations,
    ///         e.g., when one needs to move an arbitrary phantom token between accounts.
    function depositPhantomToken(address token, uint256 amount) external returns (bool);
}
