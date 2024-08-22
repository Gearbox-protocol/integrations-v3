// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";

struct MellowUnderlyingStatus {
    address underlying;
    bool allowed;
}

interface IMellowVaultAdapterEvents {
    /// @notice Emitted when the underlying is allowed / disallowed for deposit
    event SetUnderlyingStatus(address indexed token, bool newStatus);
}

interface IMellowVaultAdapterExceptions {
    /// @notice Thrown when an unsupported asset is passed as the deposited underlying
    error UnderlyingNotAllowedException(address asset);

    /// @notice Thrown when attempting to pass an asset that is not an underlying
    error UnderlyingNotFoundException(address asset);

    /// @notice Thrown when attempting to pass an amounts array with length mismatched to underlyings
    error IncorrectArrayLengthException();
}

/// @title Mellow Vault adapter interface
interface IMellowVaultAdapter is IAdapter, IMellowVaultAdapterEvents, IMellowVaultAdapterExceptions {
    /// @notice Deposits specified amounts of tokens into the vault in exchange for LP tokens.
    /// @param amounts An array specifying the amounts for each underlying token.
    /// @param minLpAmount The minimum amount of LP tokens to mint.
    /// @param deadline The time before which the operation must be completed.
    /// @notice `to` is ignored as the recipient is always the credit account
    function deposit(address, uint256[] memory amounts, uint256 minLpAmount, uint256 deadline)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    /// @notice Deposits a specififed amount of one underlying into the vault in exchange for LP tokens.
    /// @param asset The asset to deposit
    /// @param amount Amount of underlying to deposit.
    /// @param minLpAmount The minimum amount of LP tokens to mint.
    /// @param deadline The time before which the operation must be completed.
    function depositOneAsset(address asset, uint256 amount, uint256 minLpAmount, uint256 deadline)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    /// @notice Deposits the entire balance of one underlying, except the specified amount, into the vault in exchange for LP tokens.
    /// @param asset The asset to deposit
    /// @param leftoverAmount Amount of underlying to leave on the Credit Account.
    /// @param rateMinRAY The minimum exchange rate between the deposited asset and LP, in 1e27 format.
    /// @param deadline The time before which the operation must be completed.
    function depositOneAssetDiff(address asset, uint256 leftoverAmount, uint256 rateMinRAY, uint256 deadline)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Whether the underlying token is allowed for deposits
    function isUnderlyingAllowed(address token) external view returns (bool);

    /// @notice Changes the allowed status of several underlyings
    function setUnderlyingStatusBatch(MellowUnderlyingStatus[] calldata underlyings) external;
}
