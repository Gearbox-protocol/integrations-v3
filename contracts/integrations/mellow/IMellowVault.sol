// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IMellowVault {
    /// @notice Returns an array of underlying tokens of the vault.
    /// @return underlyinigTokens_ An array of underlying token addresses.
    function underlyingTokens() external view returns (address[] memory underlyinigTokens_);

    /// @notice Deposits specified amounts of tokens into the vault in exchange for LP tokens.
    /// @dev Only accessible when deposits are unlocked.
    /// @param to The address to receive LP tokens.
    /// @param amounts An array specifying the amounts for each underlying token.
    /// @param minLpAmount The minimum amount of LP tokens to mint.
    /// @param deadline The time before which the operation must be completed.
    /// @return actualAmounts The actual amounts deposited for each underlying token.
    /// @return lpAmount The amount of LP tokens minted.
    function deposit(address to, uint256[] memory amounts, uint256 minLpAmount, uint256 deadline)
        external
        returns (uint256[] memory actualAmounts, uint256 lpAmount);
}
