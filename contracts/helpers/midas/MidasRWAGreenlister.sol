// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ICreditAccountV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditAccountV3.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

import {
    CREDIT_ACCOUNT_TYPE,
    GREENLISTED_ROLE,
    IMidasRWAGreenlister
} from "../../interfaces/midas/IMidasRWAGreenlister.sol";

/// @title Midas RWA Greenlister
/// @notice Grants and revokes Midas greenlist status for Gearbox credit accounts
contract MidasRWAGreenlister is IMidasRWAGreenlister {
    bytes32 public constant override contractType = "GATEWAY::MIDAS_GREENLISTER";
    uint256 public constant override version = 3_10;

    /// @inheritdoc IMidasRWAGreenlister
    IAccessControl public immutable override accessControl;

    constructor(address _accessControl) {
        accessControl = IAccessControl(_accessControl);
    }

    /// @inheritdoc IMidasRWAGreenlister
    function grantGreenlist() external override {
        address creditAccount = msg.sender;
        _ensureCreditAccount(creditAccount);

        address borrower = _getBorrower(creditAccount);
        if (!accessControl.hasRole(GREENLISTED_ROLE, borrower)) revert BorrowerNotGreenlistedException();

        accessControl.grantRole(GREENLISTED_ROLE, creditAccount);
    }

    /// @inheritdoc IMidasRWAGreenlister
    function revokeGreenlist(address creditAccount) external override {
        _ensureCreditAccount(creditAccount);

        address borrower = _getBorrower(creditAccount);
        if (!accessControl.hasRole(GREENLISTED_ROLE, borrower)) {
            accessControl.revokeRole(GREENLISTED_ROLE, creditAccount);
        }
    }

    /// @dev Ensures that `account` implements `IVersion` and has contract type `CREDIT_ACCOUNT`
    function _ensureCreditAccount(address account) internal view {
        try IVersion(account).contractType() returns (bytes32 contractType_) {
            if (contractType_ != CREDIT_ACCOUNT_TYPE) revert NotCreditAccountException();
        } catch {
            revert NotCreditAccountException();
        }
    }

    /// @dev Returns the borrower for a valid credit account
    function _getBorrower(address creditAccount) internal view returns (address borrower) {
        address creditManager = ICreditAccountV3(creditAccount).creditManager();
        if (creditManager == address(0)) revert CreditAccountNotRecognizedException();

        (,,,,,,, borrower) = ICreditManagerV3(creditManager).creditAccountInfo(creditAccount);
        if (borrower == address(0)) revert CreditAccountNotRecognizedException();
    }
}
