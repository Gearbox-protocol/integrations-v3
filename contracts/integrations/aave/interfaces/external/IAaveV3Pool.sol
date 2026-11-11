// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

/// @title Aave V3 Pool interface (minimal)
/// @notice Subset of the Aave V3 Pool used by `AaveHorizonBridge`
interface IAaveV3Pool {
    /// @notice Supplies an `amount` of underlying asset into the reserve, receiving aTokens in return
    /// @param asset The address of the underlying asset to supply
    /// @param amount The amount to be supplied
    /// @param onBehalfOf The address that will receive the aTokens
    /// @param referralCode Integrator referral code (0 if none)
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    /// @notice Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens
    /// @param asset The address of the underlying asset to withdraw
    /// @param amount The underlying amount to withdraw
    /// @param to The address that will receive the underlying
    /// @return The final amount withdrawn
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    /// @notice Allows users to borrow a specific `amount` of the reserve underlying asset
    /// @param asset The address of the underlying asset to borrow
    /// @param amount The amount to be borrowed
    /// @param interestRateMode The interest rate mode: 2 for variable (1 is deprecated)
    /// @param referralCode Integrator referral code (0 if none)
    /// @param onBehalfOf The address that will receive the debt
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external;

    /// @notice Repays a borrowed `amount` on a specific reserve
    /// @param asset The address of the borrowed underlying asset
    /// @param amount The amount to repay
    /// @param interestRateMode The interest rate mode of the debt: 2 for variable
    /// @param onBehalfOf The address of the user who will get their debt reduced
    /// @return The final amount repaid
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        returns (uint256);

    /// @notice Returns the address of the aToken for a reserve
    /// @param asset The address of the underlying asset of the reserve
    /// @return The address of the associated aToken
    function getReserveAToken(address asset) external view returns (address);
}
