// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {ICreditAccountV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditAccountV3.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {IMarketConfigurator} from "@gearbox-protocol/permissionless/contracts/interfaces/IMarketConfigurator.sol";
import {IContractsRegister} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IContractsRegister.sol";
import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {MidasRedeemer} from "./MidasRedeemer.sol";
import {MidasLiquidator} from "./MidasLiquidator.sol";
import {MidasRedemptionVaultPhantomToken} from "./MidasRedemptionVaultPhantomToken.sol";
import {ReentrancyGuardTrait} from "@gearbox-protocol/core-v3/contracts/traits/ReentrancyGuardTrait.sol";
import {IMidasIssuanceVault} from "../../integrations/midas/IMidasIssuanceVault.sol";
import {IMidasRedemptionVault} from "../../integrations/midas/IMidasRedemptionVault.sol";
import {IMidasAccessControl, GREENLISTED_ROLE} from "../../integrations/midas/IMidasAccessControl.sol";
import {
    IMidasGateway,
    MAX_PENDING_REDEEMERS_PER_ACCOUNT,
    CREDIT_ACCOUNT_TYPE
} from "../../interfaces/midas/IMidasGateway.sol";
import {IMidasTransferMaster} from "../../interfaces/midas/IMidasTransferMaster.sol";
import {IRedemptionLogger} from "../../interfaces/IRedemptionLogger.sol";

/// @title Midas Gateway
/// @notice Gateway contract that manages issuances and redemptions from Midas vaults on behalf of Credit Accounts
/// @dev Can optionally greenlist Credit Accounts and redeemers for permissioned tokens
contract MidasGateway is ReentrancyGuardTrait, IMidasGateway {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::MIDAS";
    uint256 public constant override version = 3_11;

    /// @notice The mToken issuance vault
    address public immutable midasIssuanceVault;

    /// @notice The mToken redemption vault
    address public immutable midasRedemptionVault;

    /// @notice Address of the mToken
    address public immutable mToken;

    /// @notice Address of the quote token used for issuance and redemption
    address public immutable quoteToken;

    /// @notice Address of the redemption phantom token
    address public immutable phantomToken;

    /// @notice Whether to check that the borrower is greenlisted
    bool public immutable checkBorrowerGreenlist;

    /// @notice Address of the mToken access control contract
    address public immutable accessControl;

    /// @notice The master redeemer contract
    address public immutable masterRedeemer;

    /// @notice Address of the transfer master contract
    address public immutable transferMaster;

    /// @notice Address of the market configurator of credit accounts that are allowed to interact with the gateway
    address public immutable allowedMarketConfigurator;

    /// @notice Expected duration of a redemption request (for informational purposes)
    uint256 public immutable expectedRedemptionDuration;

    /// @notice Address of the redemption logger contract
    address public immutable redemptionLogger;

    /// @notice Mapping of accounts to corresponding redeemer contracts
    mapping(address => EnumerableSet.AddressSet) internal accountToRedeemers;

    /// @notice Mapping of accounts to corresponding pending redeemer contracts
    mapping(address => EnumerableSet.AddressSet) internal accountToPendingRedeemers;

    modifier onlyEligibleAccount() {
        if (!_isCallerEligible(msg.sender)) revert CreditAccountNotEligibleException();
        _;
    }

    /// @notice Constructor
    /// @param _midasIssuanceVault Address of the Midas Issuance Vault
    /// @param _midasRedemptionVault Address of the Midas Redemption Vault
    /// @param _quoteToken Address of the quote token used for issuance and redemption
    /// @param _isAccessControlled Whether to read and validate access control from the Midas vaults
    /// @param _allowedMarketConfigurator Address of the market configurator of credit accounts that are allowed to interact with the gateway
    /// @param _checkBorrowerGreenlist Whether to check that the borrower is greenlisted
    /// @param _expectedRedemptionDuration Expected duration of a redemption request (for informational purposes)
    /// @param _redemptionLogger Address of the redemption logger contract
    /// @param _withDelayedWithdrawals Whether to deploy a redemption phantom token for delayed withdrawals
    constructor(
        address _midasIssuanceVault,
        address _midasRedemptionVault,
        address _quoteToken,
        bool _isAccessControlled,
        address _allowedMarketConfigurator,
        bool _checkBorrowerGreenlist,
        uint256 _expectedRedemptionDuration,
        address _redemptionLogger,
        bool _withDelayedWithdrawals
    ) {
        midasIssuanceVault = _midasIssuanceVault;
        midasRedemptionVault = _midasRedemptionVault;
        quoteToken = _quoteToken;
        mToken = IMidasRedemptionVault(_midasRedemptionVault).mToken();
        address issuanceMToken = IMidasIssuanceVault(_midasIssuanceVault).mToken();

        if (mToken != issuanceMToken) {
            revert IncompatibleIssuanceAndRedemptionVaultsException();
        }

        address accessControl_;
        if (_isAccessControlled) {
            accessControl_ = IMidasIssuanceVault(_midasIssuanceVault).accessControl();
            if (accessControl_ != IMidasRedemptionVault(_midasRedemptionVault).accessControl()) {
                revert IncompatibleAccessControlsException();
            }
        }
        accessControl = accessControl_;
        checkBorrowerGreenlist = _checkBorrowerGreenlist;

        if (accessControl_ == address(0) && _checkBorrowerGreenlist) {
            revert AccessControlNotSetException();
        }

        masterRedeemer = address(new MidasRedeemer(_midasRedemptionVault, _quoteToken));
        transferMaster = address(new MidasLiquidator());
        phantomToken = _withDelayedWithdrawals
            ? address(new MidasRedemptionVaultPhantomToken(address(this), mToken, _quoteToken))
            : address(0);
        allowedMarketConfigurator = _allowedMarketConfigurator;
        expectedRedemptionDuration = _expectedRedemptionDuration;
        redemptionLogger = _redemptionLogger;
    }

    /// @notice Performs instant issuance of mToken for quote token
    /// @param amountToken Amount of quote token to deposit
    /// @param minReceiveAmount Minimum amount of mToken to receive
    /// @param referrerId Referrer ID
    /// @dev Transfers input token from sender, issues, and transfers mToken back
    function depositInstant(uint256 amountToken, uint256 minReceiveAmount, bytes32 referrerId)
        external
        nonReentrant
        onlyEligibleAccount
    {
        IERC20(quoteToken).safeTransferFrom(msg.sender, address(this), amountToken);

        uint256 balanceBefore = IERC20(mToken).balanceOf(address(this));

        IERC20(quoteToken).forceApprove(midasIssuanceVault, amountToken);
        _grantGreenlistIfRequired(address(this));
        IMidasIssuanceVault(midasIssuanceVault)
            .depositInstant(quoteToken, _convertToE18(amountToken), minReceiveAmount, referrerId);
        _revokeGreenlistIfRequired(address(this));

        uint256 amount = IERC20(mToken).balanceOf(address(this)) - balanceBefore;

        IERC20(mToken).safeTransfer(msg.sender, amount);
    }

    /// @notice Performs instant redemption of mToken for quote token
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param minReceiveAmount Minimum amount of quote token to receive
    /// @dev Transfers mToken from sender, redeems, and transfers quote token back
    function redeemInstant(uint256 amountMTokenIn, uint256 minReceiveAmount) external nonReentrant onlyEligibleAccount {
        IERC20(mToken).safeTransferFrom(msg.sender, address(this), amountMTokenIn);

        uint256 balanceBefore = IERC20(quoteToken).balanceOf(address(this));

        IERC20(mToken).forceApprove(midasRedemptionVault, amountMTokenIn);

        _grantGreenlistIfRequired(address(this));
        IMidasRedemptionVault(midasRedemptionVault)
            .redeemInstant(quoteToken, amountMTokenIn, _convertToE18(minReceiveAmount));
        _revokeGreenlistIfRequired(address(this));

        uint256 amount = IERC20(quoteToken).balanceOf(address(this)) - balanceBefore;

        IERC20(quoteToken).safeTransfer(msg.sender, amount);
    }

    /// @notice Requests a redemption of mToken for quote token
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param extraData Additional redemption data to log
    function requestRedeem(uint256 amountMTokenIn, bytes calldata extraData) external nonReentrant onlyEligibleAccount {
        address redeemer = _makeNewRedeemerForAccount(msg.sender);
        IERC20(mToken).safeTransferFrom(msg.sender, redeemer, amountMTokenIn);

        _grantGreenlistIfRequired(redeemer);
        MidasRedeemer(redeemer).requestRedeem(amountMTokenIn);
        _revokeGreenlistIfRequired(redeemer);

        _logRedemptionIfConfigured(msg.sender, redeemer, extraData);
    }

    /// @notice Withdraws tokens from funded redeemers
    /// @param amount Amount of quote token to withdraw
    function withdraw(uint256 amount) external nonReentrant {
        address[] memory redeemers = accountToPendingRedeemers[msg.sender].values();
        uint256 remainder = amount;
        for (uint256 i = 0; i < redeemers.length && remainder > 0; i++) {
            uint256 redeemerBalance = MidasRedeemer(redeemers[i]).claimableTokenOutAmount();
            if (remainder < redeemerBalance) {
                MidasRedeemer(redeemers[i]).withdraw(remainder);
                remainder = 0;
            } else {
                if (redeemerBalance > 0) {
                    MidasRedeemer(redeemers[i]).withdraw(redeemerBalance);
                    remainder -= redeemerBalance;
                }

                if (MidasRedeemer(redeemers[i]).pendingTokenOutAmount() == 0) {
                    accountToPendingRedeemers[msg.sender].remove(redeemers[i]);
                }
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
    /// @dev Can only be used when account transfers are unlocked - usually during liquidations
    function transferRedeemer(address redeemer, address newAccount) external nonReentrant onlyEligibleAccount {
        if (
            !accountToPendingRedeemers[msg.sender].contains(redeemer)
                || !IMidasTransferMaster(transferMaster).isTransferAllowed()
        ) {
            revert RedeemerTransferNotAllowedException();
        }

        if (checkBorrowerGreenlist && !IMidasAccessControl(accessControl).hasRole(GREENLISTED_ROLE, newAccount)) {
            revert NewAccountNotGreenlistedException();
        }

        accountToRedeemers[msg.sender].remove(redeemer);
        accountToPendingRedeemers[msg.sender].remove(redeemer);

        accountToRedeemers[newAccount].add(redeemer);
        accountToPendingRedeemers[newAccount].add(redeemer);

        MidasRedeemer(redeemer).setAccount(newAccount);
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
        address[] memory redeemers = accountToPendingRedeemers[account].values();
        for (uint256 i = 0; i < redeemers.length; i++) {
            pendingAmount += MidasRedeemer(redeemers[i]).pendingTokenOutAmount();
            claimableAmount += MidasRedeemer(redeemers[i]).claimableTokenOutAmount();
        }
    }

    /// @notice Returns the pending redeemers for an account
    /// @param account The account to check
    /// @return redeemers The pending redeemers for the account
    function pendingRedeemers(address account) external view returns (address[] memory redeemers) {
        return accountToPendingRedeemers[account].values();
    }

    /// @dev Internal function to get the redeemer for an account, or create a new one if it doesn't exist
    /// @param account The account to get the redeemer for
    function _makeNewRedeemerForAccount(address account) internal returns (address redeemer) {
        if (accountToPendingRedeemers[account].length() >= MAX_PENDING_REDEEMERS_PER_ACCOUNT) {
            revert MaxPendingRedeemersPerAccountException();
        }

        redeemer = Clones.clone(masterRedeemer);
        MidasRedeemer(redeemer).setAccount(account);

        accountToRedeemers[account].add(redeemer);
        accountToPendingRedeemers[account].add(redeemer);
    }

    /// @dev Logs redemption initiation if a logger is configured
    function _logRedemptionIfConfigured(address creditAccount, address redeemer, bytes calldata extraData) internal {
        if (redemptionLogger != address(0)) {
            IRedemptionLogger(redemptionLogger).logRedemption(creditAccount, redeemer, extraData);
        }
    }

    /// @dev Converts the token amount to 18 decimals, which is accepted by Midas
    function _convertToE18(uint256 amount) internal view returns (uint256) {
        uint256 tokenUnit = 10 ** IERC20Metadata(quoteToken).decimals();
        if (tokenUnit == WAD) return amount;
        return amount * WAD / tokenUnit;
    }

    /// @dev Checks if a caller is eligible to interact with the gateway
    function _isCallerEligible(address caller) internal view returns (bool) {
        if (!_isCreditAccount(caller)) return false;

        address creditManager = ICreditAccountV3(caller).creditManager();
        if (creditManager == address(0)) return false;

        (,,,,,,, address borrower) = ICreditManagerV3(creditManager).creditAccountInfo(caller);
        if (borrower == address(0)) return false;

        if (allowedMarketConfigurator != address(0) && !_isAccountCreditManagerFromMarketConfigurator(creditManager)) {
            return false;
        }

        return !checkBorrowerGreenlist || IMidasAccessControl(accessControl).hasRole(GREENLISTED_ROLE, borrower);
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

    /// @dev Grants the GREENLISTED_ROLE to an account if the Midas access control is set
    function _grantGreenlistIfRequired(address account) internal {
        if (accessControl == address(0)) return;
        IMidasAccessControl(accessControl).grantRole(GREENLISTED_ROLE, account);
    }

    /// @dev Grants the GREENLISTED_ROLE to an account if the Midas access control is not set
    function _revokeGreenlistIfRequired(address account) internal {
        if (accessControl == address(0)) return;
        IMidasAccessControl(accessControl).revokeRole(GREENLISTED_ROLE, account);
    }
}
