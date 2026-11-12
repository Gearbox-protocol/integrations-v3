// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

/// @title Investor-aware borrower interface
/// @notice Minimal surface for CA borrowers (e.g. SecuritizeWallet) that expose the economic owner
interface IInvestorAware {
    /// @notice Economic owner / investor behind the credit-account borrower
    function getInvestor() external view returns (address);
}
