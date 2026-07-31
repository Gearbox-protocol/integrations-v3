// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {ICreditAccountV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditAccountV3.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";

import {MidasRedeemer} from "./MidasRedeemer.sol";
import {MidasLiquidator} from "./MidasLiquidator.sol";
import {MidasDegenNFT} from "./MidasDegenNFT.sol";
import {MidasRedemptionVaultPhantomToken} from "./MidasRedemptionVaultPhantomToken.sol";
import {ReentrancyGuardTrait} from "@gearbox-protocol/core-v3/contracts/traits/ReentrancyGuardTrait.sol";
import {CACheckerTrait} from "../common/CACheckerTrait.sol";
import {RedemptionLoggingTrait} from "../common/RedemptionLoggingTrait.sol";
import {ICAChecker} from "../common/interfaces/ICAChecker.sol";
import {IMidasRedemptionVault} from "./interfaces/external/IMidasRedemptionVault.sol";
import {IMidasAccessControl, STANDARD_GREENLISTED_ROLE} from "./interfaces/external/IMidasAccessControl.sol";
import {IMidasGateway, MidasMode, MAX_PENDING_REDEEMERS_PER_ACCOUNT} from "./interfaces/IMidasGateway.sol";
import {IMidasTransferMaster} from "./interfaces/IMidasTransferMaster.sol";

bytes32 constant SALT = keccak256("MidasGateway");

/// @title Midas Gateway
/// @notice Gateway that manages delayed Midas redemptions on behalf of Credit Accounts
/// @dev Can optionally greenlist Credit Accounts and redeemers for permissioned tokens
contract MidasGateway is ReentrancyGuardTrait, CACheckerTrait, RedemptionLoggingTrait, IMidasGateway {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::MIDAS";
    uint256 public constant override version = 3_11;

    /// @notice The mToken redemption vault
    address public immutable override midasRedemptionVault;

    /// @notice Address of the mToken
    address public immutable override mToken;

    /// @notice Address of the quote token used for redemption
    address public immutable override quoteToken;

    /// @notice Address of the redemption phantom token
    address public immutable override phantomToken;

    /// @notice Access mode of the gateway
    MidasMode public immutable override mode;

    /// @notice Address of the mToken access control contract
    address public immutable override accessControl;

    /// @notice The master redeemer contract
    address public immutable masterRedeemer;

    /// @notice Address of the transfer master contract
    address public immutable override transferMaster;

    /// @notice Expected duration of a redemption request (for informational purposes)
    uint256 public immutable expectedRedemptionDuration;

    /// @notice Identifier of the vault's greenlisted role in Midas access control
    bytes32 public immutable override greenlistedRole;

    /// @notice Address of the Midas Degen NFT, or zero outside Permissioned mode
    address public immutable override degenNFT;

    /// @dev Ownership set: every redeemer ever created for an account, pruned only when one is transferred away.
    ///      Membership is what authorizes `withdrawFromRedeemer`, so stranded funds stay recoverable indefinitely.
    mapping(address => EnumerableSet.AddressSet) internal accountToRedeemers;

    /// @dev Collateral set: the subset of `accountToRedeemers` that the phantom token still prices. A redeemer leaves
    ///      it once fully settled or transferred away, and there is no path back in.
    mapping(address => EnumerableSet.AddressSet) internal accountToPendingRedeemers;

    /// @notice Constructor
    /// @param _midasRedemptionVault Address of the Midas Redemption Vault
    /// @param _quoteToken Address of the quote token used for redemption
    /// @param _mode Access mode of the gateway
    /// @param _allowedMarketConfigurator Address of the market configurator of credit accounts that are allowed to interact with the gateway
    /// @param _expectedRedemptionDuration Expected duration of a redemption request (for informational purposes)
    /// @param _withDelayedWithdrawals Whether to deploy a redemption phantom token for delayed withdrawals
    /// @param _addressProvider Address of the Gearbox AddressProviderV3
    constructor(
        address _midasRedemptionVault,
        address _quoteToken,
        MidasMode _mode,
        address _allowedMarketConfigurator,
        uint256 _expectedRedemptionDuration,
        bool _withDelayedWithdrawals,
        address _addressProvider
    ) CACheckerTrait(_allowedMarketConfigurator) RedemptionLoggingTrait(_addressProvider) {
        midasRedemptionVault = _midasRedemptionVault;
        quoteToken = _quoteToken;
        mode = _mode;
        mToken = IMidasRedemptionVault(_midasRedemptionVault).mToken();

        if (_mode == MidasMode.Permissionless) {
            accessControl = address(0);
            greenlistedRole = 0;
        } else {
            accessControl = IMidasRedemptionVault(_midasRedemptionVault).accessControl();
            if (accessControl == address(0)) revert AccessControlNotSetException();

            try IMidasRedemptionVault(_midasRedemptionVault).greenlistedRole() returns (bytes32 role) {
                greenlistedRole = role;
            } catch {
                greenlistedRole = STANDARD_GREENLISTED_ROLE;
            }
        }

        masterRedeemer = address(new MidasRedeemer{salt: SALT}(_midasRedemptionVault, _quoteToken));
        transferMaster = address(new MidasLiquidator{salt: SALT}());
        phantomToken = _withDelayedWithdrawals
            ? address(new MidasRedemptionVaultPhantomToken{salt: SALT}(address(this), mToken, _quoteToken))
            : address(0);

        // only gates account opening once the market's credit facade is configured to use it
        degenNFT = _mode == MidasMode.Permissioned
            ? address(new MidasDegenNFT{salt: SALT}(accessControl, greenlistedRole))
            : address(0);

        expectedRedemptionDuration = _expectedRedemptionDuration;
    }

    /// @notice Requests a redemption of mToken for quote token
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param extraData Additional redemption data to log
    /// @dev Every request gets its own redeemer clone, since Midas settles requests independently and a redeemer
    ///      can only ever hold one of them
    function requestRedeem(uint256 amountMTokenIn, bytes calldata extraData) external nonReentrant onlyEligibleAccount {
        address redeemer = _makeNewRedeemerForAccount(msg.sender);

        IERC20(mToken).safeTransferFrom(msg.sender, redeemer, amountMTokenIn);
        MidasRedeemer(redeemer).requestRedeem(amountMTokenIn);
        _logRedemption(msg.sender, redeemer, extraData);
    }

    /// @notice Withdraws tokens from funded redeemers
    /// @param amount Amount of quote token to withdraw
    /// @dev Drains redeemers in set order and reverts if their claimable balances do not add up to `amount`
    function withdraw(uint256 amount) external nonReentrant {
        address[] memory redeemers_ = accountToPendingRedeemers[msg.sender].values();
        uint256 remainder = amount;

        for (uint256 i = 0; i < redeemers_.length && remainder > 0; i++) {
            MidasRedeemer redeemer = MidasRedeemer(redeemers_[i]);
            uint256 claimable = redeemer.claimableTokenOutAmount();

            // the last redeemer only needs to be drained partially, and stays pending with the leftover balance
            if (remainder < claimable) {
                redeemer.withdraw(remainder);
                remainder = 0;
                break;
            }

            if (claimable > 0) {
                redeemer.withdraw(claimable);
                remainder -= claimable;
            }

            if (redeemer.pendingTokenOutAmount() == 0) {
                accountToPendingRedeemers[msg.sender].remove(address(redeemer));
            }
        }

        if (remainder > 0) revert InsufficientBalanceException();
    }

    /// @notice Withdraws tokens from a specific redeemer
    /// @param redeemer The redeemer to withdraw from
    /// @param amount The amount to withdraw
    /// @dev Can be used to withdraw from a redeemer that no longer counts as collateral,
    ///      if there are funds stranded on it
    function withdrawFromRedeemer(address redeemer, uint256 amount) external nonReentrant {
        if (!accountToRedeemers[msg.sender].contains(redeemer)) {
            revert RedeemerNotOwnedByAccountException();
        }

        MidasRedeemer(redeemer).withdraw(amount);

        if (
            MidasRedeemer(redeemer).pendingTokenOutAmount() == 0
                && MidasRedeemer(redeemer).claimableTokenOutAmount() == 0
        ) {
            accountToPendingRedeemers[msg.sender].remove(redeemer);
        }
    }

    /// @notice Transfers a redeemer to a new account
    /// @param redeemer The redeemer to transfer
    /// @param newAccount The new account to transfer the redeemer to
    /// @dev Can only be used when account transfers are unlocked for a specific account - usually during liquidations
    /// @dev The redeemer is removed forever from pending redeemers, which means it can only be transferred once
    /// @dev Transfers to self and to the zero address are rejected: both would drop the redeemer from the pending
    ///      set with no way back, silently removing the position from collateral valuation
    function transferRedeemer(address redeemer, address newAccount) external nonReentrant onlyEligibleAccount {
        if (
            newAccount == msg.sender || newAccount == address(0)
                || !accountToPendingRedeemers[msg.sender].contains(redeemer)
                || !IMidasTransferMaster(transferMaster).isTransferAllowed(msg.sender)
        ) {
            revert RedeemerTransferNotAllowedException();
        }

        if (!_isGreenlistedIfRequired(newAccount)) revert NewAccountNotGreenlistedException();

        accountToRedeemers[msg.sender].remove(redeemer);
        accountToPendingRedeemers[msg.sender].remove(redeemer);

        accountToRedeemers[newAccount].add(redeemer);

        MidasRedeemer(redeemer).setAccount(newAccount);
    }

    /// @notice Gives an account a greenlisted role
    /// @dev Permissioned mTokens require the greenlist for transfers, so an account needs it before it can
    ///      hold or move them. The grant is permanent — the gateway never revokes it.
    function receiveGreenlist() external nonReentrant onlyEligibleAccount {
        if (mode != MidasMode.Permissioned) {
            revert GreenlistRequestedInNonPermissionedModeException();
        }

        _grantGreenlistIfRequired(msg.sender);
    }

    /// @notice Returns the pending and claimable amounts of quote token for an account, for all currently counted redeemers
    /// @param account The account to check
    /// @return pendingAmount The pending amount of quote token
    /// @return claimableAmount The claimable amount of quote token
    function pendingAndClaimableTokenOutAmounts(address account)
        external
        view
        returns (uint256 pendingAmount, uint256 claimableAmount)
    {
        address[] memory redeemers_ = accountToPendingRedeemers[account].values();
        for (uint256 i = 0; i < redeemers_.length; ++i) {
            pendingAmount += MidasRedeemer(redeemers_[i]).pendingTokenOutAmount();
            claimableAmount += MidasRedeemer(redeemers_[i]).claimableTokenOutAmount();
        }
    }

    /// @notice Returns the pending redeemers for an account
    /// @param account The account to check
    /// @return The pending redeemers for the account
    function pendingRedeemers(address account) external view returns (address[] memory) {
        return accountToPendingRedeemers[account].values();
    }

    /// @notice Returns all redeemers for an account
    /// @param account The account to check
    /// @return The redeemers for the account
    function redeemers(address account) external view returns (address[] memory) {
        return accountToRedeemers[account].values();
    }

    /// @notice Returns whether a credit account owner satisfies the greenlist requirement, and the mToken address
    /// @dev Answers only the owner-level permission question. It is not the full `onlyEligibleAccount` gate, which
    ///      additionally requires the *caller* to be a credit account of the allowed market configurator.
    function isEligibleAccountOwner(address account) external view returns (bool, address) {
        return (_isGreenlistedIfRequired(account), mToken);
    }

    /// @notice Whether `account` is eligible to interact with the gateway
    /// @dev Extends the base CA/MC check with the Permissioned-mode greenlist requirement on the borrower
    function isAccountEligible(address account) public view override(CACheckerTrait, ICAChecker) returns (bool) {
        if (!super.isAccountEligible(account)) return false;

        (,,,,,,, address borrower) =
            ICreditManagerV3(ICreditAccountV3(account).creditManager()).creditAccountInfo(account);
        return _isGreenlistedIfRequired(borrower);
    }

    /// @dev Deploys a fresh redeemer clone for `account` and registers it in both sets
    function _makeNewRedeemerForAccount(address account) internal returns (address redeemer) {
        if (accountToPendingRedeemers[account].length() >= MAX_PENDING_REDEEMERS_PER_ACCOUNT) {
            revert MaxPendingRedeemersPerAccountException();
        }

        redeemer = Clones.clone(masterRedeemer);
        MidasRedeemer(redeemer).setAccount(account);

        accountToRedeemers[account].add(redeemer);
        accountToPendingRedeemers[account].add(redeemer);
        _grantGreenlistIfRequired(redeemer);
    }

    /// @dev Whether `account` satisfies the gateway's greenlist requirement
    /// @dev Outside Permissioned mode there is no greenlist requirement, so any account satisfies it
    function _isGreenlistedIfRequired(address account) internal view returns (bool) {
        return mode != MidasMode.Permissioned || IMidasAccessControl(accessControl).hasRole(greenlistedRole, account);
    }

    /// @dev Grants the greenlisted role, or does nothing in Permissionless mode where there is no access control
    function _grantGreenlistIfRequired(address account) internal {
        if (accessControl != address(0)) {
            IMidasAccessControl(accessControl).grantRole(greenlistedRole, account);
        }
    }
}
