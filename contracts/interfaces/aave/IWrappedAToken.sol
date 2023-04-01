// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAToken} from "../../integrations/aave/IAToken.sol";
import {ILendingPool} from "../../integrations/aave/ILendingPool.sol";

/// @title Wrapped aToken interface
interface IWrappedAToken is IERC20Metadata {
    /// @notice Emitted on deposit
    /// @param account Account that performed deposit
    /// @param assets Amount of deposited aTokens
    /// @param shares Amount of waTokens minted to account
    event Deposit(address indexed account, uint256 assets, uint256 shares);

    /// @notice Emitted on withdrawal
    /// @param account Account that performed withdrawal
    /// @param assets Amount of withdrawn aTokens
    /// @param shares Amount of waTokens burnt from account
    event Withdraw(address indexed account, uint256 assets, uint256 shares);

    /// @notice Underlying aToken
    function aToken() external view returns (IAToken);

    /// @notice Underlying token
    function underlying() external view returns (IERC20);

    /// @notice Aave lending pool
    function lendingPool() external view returns (ILendingPool);

    /// @notice Returns amount of aTokens belonging to given account (increases as interest is accrued)
    function balanceOfUnderlying(address account) external view returns (uint256);

    /// @notice Returns amount of aTokens per waToken, scaled by 1e18
    function exchangeRate() external view returns (uint256);

    /// @notice Deposit given amount of aTokens (aToken must be approved before the call)
    /// @param assets Amount of aTokens to deposit in exchange for waTokens
    /// @return shares Amount of waTokens minted to the caller
    function deposit(uint256 assets) external returns (uint256 shares);

    /// @notice Deposit given amount underlying tokens (underlying must be approved before the call)
    /// @param assets Amount of underlying tokens to deposit in exchange for waTokens
    /// @return shares Amount of waTokens minted to the caller
    function depositUnderlying(uint256 assets) external returns (uint256 shares);

    /// @notice Withdraw given amount of waTokens for aTokens
    /// @param shares Amount of waTokens to burn in exchange for aTokens
    /// @return assets Amount of aTokens sent to the caller
    function withdraw(uint256 shares) external returns (uint256 assets);

    /// @notice Withdraw given amount of waTokens for underlying tokens
    /// @param shares Amount of waTokens to burn in exchange for underlying tokens
    /// @return assets Amount of underlying tokens sent to the caller
    function withdrawUnderlying(uint256 shares) external returns (uint256 assets);
}
