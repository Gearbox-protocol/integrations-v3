// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {ICreditAccountV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditAccountV3.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {IMarketConfigurator} from "@gearbox-protocol/permissionless/contracts/interfaces/IMarketConfigurator.sol";
import {IContractsRegister} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IContractsRegister.sol";

import {ICAChecker, CREDIT_ACCOUNT_TYPE} from "./interfaces/ICAChecker.sol";

/// @title Credit account checker trait
/// @notice Shared eligibility checks for gateways that only accept credit accounts from a given market configurator
/// @dev `contractType` and `creditManager` are self-reported, so neither is trusted on its own: the claimed
///      credit manager must vouch for the account as one of its accounts, and must itself be registered in the
///      allowed market configurator's register. The register is the only trust anchor here — without it the
///      whole chain is forgeable by a contract that answers the same way.
abstract contract CACheckerTrait is ICAChecker {
    /// @notice Address of the market configurator of credit accounts that are allowed to interact with the gateway
    address public immutable override allowedMarketConfigurator;

    /// @notice Verifies that the caller is eligible to interact with the gateway
    modifier onlyEligibleAccount() {
        if (!isAccountEligible(msg.sender)) revert CreditAccountNotEligibleException();
        _;
    }

    /// @notice Constructor
    /// @param allowedMarketConfigurator_ Address of the market configurator of credit accounts that are allowed to
    ///        interact with the gateway
    constructor(address allowedMarketConfigurator_) {
        if (allowedMarketConfigurator_ == address(0)) revert MarketConfiguratorNotSetException();
        allowedMarketConfigurator = allowedMarketConfigurator_;
    }

    /// @notice Whether `account` is an eligible credit account of `allowedMarketConfigurator`
    /// @dev Virtual so subclasses can add extra checks (e.g. a greenlist requirement)
    function isAccountEligible(address account) public view virtual override returns (bool) {
        if (!_isCreditAccount(account)) return false;

        address creditManager = ICreditAccountV3(account).creditManager();
        if (creditManager == address(0)) return false;

        (,,,,,,, address borrower) = ICreditManagerV3(creditManager).creditAccountInfo(account);
        if (borrower == address(0)) return false;

        return _isAccountCreditManagerFromMarketConfigurator(creditManager);
    }

    /// @dev Checks whether `account` implements `IVersion` and has contract type `CREDIT_ACCOUNT`
    function _isCreditAccount(address account) internal view returns (bool) {
        try IVersion(account).contractType() returns (bytes32 contractType_) {
            if (contractType_ != CREDIT_ACCOUNT_TYPE) return false;
        } catch {
            return false;
        }

        return true;
    }

    /// @dev Checks whether `creditManager` is registered as a credit manager in the market configurator
    function _isAccountCreditManagerFromMarketConfigurator(address creditManager) internal view returns (bool) {
        address contractsRegister = IMarketConfigurator(allowedMarketConfigurator).contractsRegister();
        return IContractsRegister(contractsRegister).isCreditManager(creditManager);
    }
}
