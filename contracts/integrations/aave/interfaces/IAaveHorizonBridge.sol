// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {ICAChecker} from "../../common/interfaces/ICAChecker.sol";

/// @title Aave Horizon Bridge interface
/// @notice Moves RWA aTokens between a Credit Account and its economic owner, and borrows/repays on that owner's
///         Horizon position. If the CM borrower exposes `getInvestor()`, that address is used as the owner.
interface IAaveHorizonBridge is IVersion, ICAChecker {
    /// @dev Thrown when the credit account's owner is the credit account itself
    error CreditAccountOwnerIsCreditAccountException();

    /// @notice Aave V3 Horizon Pool
    function pool() external view returns (address);

    /// @notice Aave Horizon RWA aToken manager
    function rwaATokenManager() external view returns (address);

    /// @notice Integrator referral code passed to Aave `borrow`
    function referralCode() external view returns (uint16);

    /// @notice Moves aTokens from the CA to its economic owner and borrows `debtToken` to the CA on their behalf
    /// @param aToken RWA aToken held by the CA (already supplied via the Pool adapter)
    /// @param debtToken Asset to borrow
    /// @param aTokenAmount Amount of aTokens to move from the CA to the owner
    /// @param borrowAmount Amount of `debtToken` to borrow on behalf of the owner and send to the CA
    function openPosition(address aToken, address debtToken, uint256 aTokenAmount, uint256 borrowAmount) external;

    /// @notice Repays the economic owner's Horizon debt from the CA and moves aTokens back to the CA
    /// @param aToken RWA aToken to return to the CA (withdraw separately via the Pool adapter)
    /// @param debtToken Asset used to repay the owner's variable debt
    /// @param repayAmount Amount of `debtToken` to pull from the CA and repay
    /// @param aTokenAmount Amount of aTokens to move from the owner to the CA
    function closePosition(address aToken, address debtToken, uint256 repayAmount, uint256 aTokenAmount) external;
}
