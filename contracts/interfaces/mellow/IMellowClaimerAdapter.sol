// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IPhantomTokenAdapter} from "../IPhantomTokenAdapter.sol";

struct MellowMultivaultStatus {
    address multiVault;
    address stakedPhantomToken;
    bool allowed;
}

interface IMellowClaimerAdapterExceptions {
    /// @notice Error thrown when the actually claimed amount is less than the requested amount
    error InsufficientClaimedException();

    /// @notice Thrown when the staked phantom token field does not match the multivault
    error InvalidMultivaultException();

    /// @notice Thrown when the staked phantom token added with the vault has incorrect parameters
    error InvalidStakedPhantomTokenException();

    /// @notice Thrown when the multivault is not allowed
    error MultivaultNotAllowedException();
}

/// @title Mellow ERC4626 Vault adapter interface
/// @notice Interface for the adapter to interact with Mellow's ERC4626 vaults
interface IMellowClaimerAdapter is IPhantomTokenAdapter, IMellowClaimerAdapterExceptions {
    function multiAccept(address multiVault, uint256[] calldata subvaultIndices, uint256[][] calldata indices)
        external
        returns (bool);

    function multiAcceptAndClaim(
        address multiVault,
        uint256[] calldata subvaultIndices,
        uint256[][] calldata indices,
        address,
        uint256 maxAssets
    ) external returns (bool);

    function getMultiVaultSubvaultIndices(address multiVault)
        external
        view
        returns (uint256[] memory subvaultIndices, uint256[][] memory withdrawalIndices);

    function getUserSubvaultIndices(address multiVault, address user)
        external
        view
        returns (uint256[] memory subvaultIndices, uint256[][] memory withdrawalIndices);

    function allowedMultivaults() external view returns (address[] memory);

    function setMultivaultStatusBatch(MellowMultivaultStatus[] calldata multivaults) external;
}
