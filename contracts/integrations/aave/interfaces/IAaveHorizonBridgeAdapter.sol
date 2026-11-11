// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

/// @notice Status update for an allowed aToken or debt token
struct AaveHorizonTokenStatus {
    address token;
    bool allowed;
}

/// @title Aave Horizon Bridge adapter interface
interface IAaveHorizonBridgeAdapter is IAdapter {
    /// @notice Emitted when an aToken is allowed / disallowed
    event SetATokenStatus(address indexed token, bool allowed);

    /// @notice Emitted when a debt token is allowed / disallowed
    event SetDebtTokenStatus(address indexed token, bool allowed);

    /// @notice Bridge address (same as `targetContract`)
    function bridge() external view returns (address);

    /// @notice Whether `token` is allowed as an RWA aToken
    function isATokenAllowed(address token) external view returns (bool);

    /// @notice Whether `token` is allowed as a debt token
    function isDebtTokenAllowed(address token) external view returns (bool);

    /// @notice List of allowed RWA aTokens
    function allowedATokens() external view returns (address[] memory);

    /// @notice List of allowed debt tokens
    function allowedDebtTokens() external view returns (address[] memory);

    /// @notice Moves aTokens from the CA to its owner and borrows into the CA
    /// @param aToken RWA aToken held by the CA
    /// @param debtToken Asset to borrow
    /// @param aTokenAmount Amount of aTokens to move to the owner
    /// @param borrowAmount Amount of `debtToken` to borrow into the CA
    function openPosition(address aToken, address debtToken, uint256 aTokenAmount, uint256 borrowAmount)
        external
        returns (bool useSafePrices);

    /// @notice Repays the owner's debt from the CA and moves aTokens back to the CA
    /// @param aToken RWA aToken to return to the CA
    /// @param debtToken Asset used to repay
    /// @param repayAmount Amount of `debtToken` to repay
    /// @param aTokenAmount Amount of aTokens to move from the owner to the CA
    function closePosition(address aToken, address debtToken, uint256 repayAmount, uint256 aTokenAmount)
        external
        returns (bool useSafePrices);

    /// @notice Allows / disallows a batch of RWA aTokens
    function setATokenStatusBatch(AaveHorizonTokenStatus[] calldata tokens) external;

    /// @notice Allows / disallows a batch of debt tokens
    function setDebtTokenStatusBatch(AaveHorizonTokenStatus[] calldata tokens) external;
}
