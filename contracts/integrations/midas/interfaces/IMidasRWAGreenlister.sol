// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

// Gearbox credit account contract type
bytes32 constant CREDIT_ACCOUNT_TYPE = "CREDIT_ACCOUNT";

// Midas AccessControl role that can grant and revoke `GREENLISTED_ROLE`
bytes32 constant GREENLIST_OPERATOR_ROLE = 0x77c5b782690f31cd39b1abf2448215259a688a75920040c399d96a676bd1999d;

// Midas AccessControl role granted to greenlisted addresses
bytes32 constant GREENLISTED_ROLE = 0xd2576bd6a4c5558421de15cb8ecdf4eb3282aac06b94d4f004e8cd0d00f3ebd8;

interface IMidasRWAGreenlister is IVersion {
    /// @notice Thrown when the address is not a valid credit account
    error NotCreditAccountException();

    /// @notice Thrown when the credit account is not recognized
    error CreditAccountNotRecognizedException();

    /// @notice Thrown when the credit account's borrower is not greenlisted
    error BorrowerNotGreenlistedException();

    /// @notice External Midas AccessControl contract
    function accessControl() external view returns (IAccessControl);

    /// @notice Grants `GREENLISTED_ROLE` to the caller if it is a valid credit account
    ///         whose borrower is already greenlisted in the external AccessControl contract
    function grantGreenlist() external;

    /// @notice Revokes `GREENLISTED_ROLE` from a credit account if its borrower is no longer greenlisted
    /// @param creditAccount Credit account to revoke greenlist status from
    function revokeGreenlist(address creditAccount) external;
}
