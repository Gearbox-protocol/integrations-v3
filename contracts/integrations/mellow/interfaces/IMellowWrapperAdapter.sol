// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

struct MellowVaultStatus {
    address vault;
    bool allowed;
}

interface IMellowWrapperAdapterEvents {
    /// @notice Emitted when the underlying is allowed / disallowed for deposit
    event SetVaultStatus(address indexed token, bool newStatus);
}

interface IMellowWrapperAdapterExceptions {
    /// @notice Thrown when attempting to deposit into an unsupported vault
    error VaultNotAllowedException(address asset);
}

/// @title Mellow Vault adapter interface
interface IMellowWrapperAdapter is IAdapter, IMellowWrapperAdapterEvents, IMellowWrapperAdapterExceptions {
    function deposit(address depositToken, uint256 amount, address vault, address receiver, address referral)
        external
        returns (bool);

    function depositDiff(uint256 leftoverAmount, address vault) external returns (bool);

    function allowedVaults() external view returns (address[] memory);

    function setVaultStatusBatch(MellowVaultStatus[] calldata vaults) external;
}
