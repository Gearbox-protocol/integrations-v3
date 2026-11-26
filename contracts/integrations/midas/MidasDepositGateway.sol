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

import {MidasDepositor} from "./MidasDepositor.sol";
import {MidasDepositVaultPhantomToken} from "./MidasDepositVaultPhantomToken.sol";
import {ReentrancyGuardTrait} from "@gearbox-protocol/core-v3/contracts/traits/ReentrancyGuardTrait.sol";
import {CACheckerTrait} from "../common/CACheckerTrait.sol";
import {RedemptionLoggingTrait} from "../common/RedemptionLoggingTrait.sol";
import {ICAChecker} from "../common/interfaces/ICAChecker.sol";
import {IMidasDepositVault} from "./interfaces/external/IMidasDepositVault.sol";
import {IMidasAccessControl, STANDARD_GREENLISTED_ROLE} from "./interfaces/external/IMidasAccessControl.sol";
import {IMidasDepositGateway, MAX_PENDING_DEPOSITORS_PER_ACCOUNT} from "./interfaces/IMidasDepositGateway.sol";
import {MidasMode} from "./interfaces/IMidasRedemptionGateway.sol";
import {IMidasTransferMaster} from "./interfaces/IMidasTransferMaster.sol";

bytes32 constant DEPOSIT_GATEWAY_SALT = keccak256("MidasDepositGateway");

/// @title Midas Deposit Gateway
/// @notice Gateway that manages delayed Midas deposits on behalf of Credit Accounts
/// @dev Can optionally greenlist Credit Accounts and depositors for permissioned tokens
contract MidasDepositGateway is ReentrancyGuardTrait, CACheckerTrait, RedemptionLoggingTrait, IMidasDepositGateway {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::MIDAS_DEPOSIT";
    uint256 public constant override version = 3_10;

    /// @notice The mToken deposit vault
    address public immutable override midasDepositVault;

    /// @notice Address of the mToken
    address public immutable override mToken;

    /// @notice Address of the payment token used for deposits
    address public immutable override tokenIn;

    /// @notice Address of the deposit phantom token
    address public immutable override phantomToken;

    /// @notice Access mode of the gateway
    MidasMode public immutable override mode;

    /// @notice Address of the mToken access control contract
    address public immutable override accessControl;

    /// @notice The master depositor contract
    address public immutable masterDepositor;

    /// @notice Address of the transfer master contract
    address public immutable override transferMaster;

    /// @notice Referrer ID used for all deposits through this gateway
    bytes32 public immutable override referrerId;

    /// @notice Expected duration of a deposit request (for informational purposes)
    uint256 public immutable expectedDepositDuration;

    /// @notice Identifier of the vault's greenlisted role in Midas access control
    bytes32 public immutable override greenlistedRole;

    /// @dev Ownership set: every depositor ever created for an account, pruned only when one is transferred away.
    ///      Membership is what authorizes `withdrawFromDepositor`, so stranded funds stay recoverable indefinitely.
    mapping(address => EnumerableSet.AddressSet) internal accountToDepositors;

    /// @dev Collateral set: the subset of `accountToDepositors` that the phantom token still prices. A depositor leaves
    ///      it once fully settled or transferred away, and there is no path back in.
    mapping(address => EnumerableSet.AddressSet) internal accountToPendingDepositors;

    /// @notice Constructor
    /// @param _midasDepositVault Address of the Midas Deposit Vault
    /// @param _tokenIn Address of the payment token used for deposits
    /// @param _referrerId Referrer ID to use for all deposits
    /// @param _mode Access mode of the gateway
    /// @param _allowedMarketConfigurator Address of the market configurator of credit accounts that are allowed to interact with the gateway
    /// @param _expectedDepositDuration Expected duration of a deposit request (for informational purposes)
    /// @param _withDelayedDeposits Whether to deploy a deposit phantom token for delayed deposits
    /// @param _priceDepositsByCurrentRate Whether to price deposits by current or initial mToken rate
    /// @param _transferMaster Shared Midas liquidator / transfer master
    /// @param _addressProvider Address of the Gearbox AddressProviderV3
    constructor(
        address _midasDepositVault,
        address _tokenIn,
        bytes32 _referrerId,
        MidasMode _mode,
        address _allowedMarketConfigurator,
        uint256 _expectedDepositDuration,
        bool _withDelayedDeposits,
        bool _priceDepositsByCurrentRate,
        address _transferMaster,
        address _addressProvider
    ) CACheckerTrait(_allowedMarketConfigurator) RedemptionLoggingTrait(_addressProvider) {
        midasDepositVault = _midasDepositVault;
        tokenIn = _tokenIn;
        referrerId = _referrerId;
        mode = _mode;
        transferMaster = _transferMaster;
        mToken = IMidasDepositVault(_midasDepositVault).mToken();

        if (_mode == MidasMode.Permissionless) {
            accessControl = address(0);
            greenlistedRole = 0;
        } else {
            accessControl = IMidasDepositVault(_midasDepositVault).accessControl();
            if (accessControl == address(0)) revert AccessControlNotSetException();

            try IMidasDepositVault(_midasDepositVault).greenlistedRole() returns (bytes32 role) {
                greenlistedRole = role;
            } catch {
                greenlistedRole = STANDARD_GREENLISTED_ROLE;
            }
        }

        masterDepositor = address(
            new MidasDepositor{salt: DEPOSIT_GATEWAY_SALT}(
                _midasDepositVault, _tokenIn, _referrerId, _priceDepositsByCurrentRate
            )
        );
        phantomToken = _withDelayedDeposits
            ? address(new MidasDepositVaultPhantomToken{salt: DEPOSIT_GATEWAY_SALT}(address(this), mToken, _tokenIn))
            : address(0);

        expectedDepositDuration = _expectedDepositDuration;
    }

    /// @notice Requests a deposit of payment token for mToken
    /// @param amountTokenIn Amount of payment token to deposit (native decimals)
    /// @param extraData Additional deposit data to log
    /// @dev Every request gets its own depositor clone, since Midas settles requests independently and a depositor
    ///      can only ever hold one of them
    function requestDeposit(uint256 amountTokenIn, bytes calldata extraData) external nonReentrant onlyEligibleAccount {
        address depositor = _makeNewDepositorForAccount(msg.sender);

        IERC20(tokenIn).safeTransferFrom(msg.sender, depositor, amountTokenIn);
        MidasDepositor(depositor).requestDeposit(amountTokenIn);
        _logRedemption(msg.sender, depositor, extraData);
    }

    /// @notice Requests a deposit with a non-zero instant share
    /// @param amountTokenIn Amount of payment token to deposit (native decimals)
    /// @param instantShare Fraction (in bp) of the amount to deposit instantly
    /// @param minReceiveAmountInstantShare Minimum amount of mToken to receive for the instant share
    /// @param extraData Additional deposit data to log
    function requestDepositHybrid(
        uint256 amountTokenIn,
        uint256 instantShare,
        uint256 minReceiveAmountInstantShare,
        bytes calldata extraData
    ) external nonReentrant onlyEligibleAccount {
        address depositor = _makeNewDepositorForAccount(msg.sender);

        IERC20(tokenIn).safeTransferFrom(msg.sender, depositor, amountTokenIn);
        MidasDepositor(depositor).requestDepositHybrid(amountTokenIn, instantShare, minReceiveAmountInstantShare);
        _logRedemption(msg.sender, depositor, extraData);
    }

    /// @notice Withdraws minted mToken from funded depositors
    /// @param amount Amount of mToken to withdraw
    /// @dev Drains depositors in set order and reverts if their claimable balances do not add up to `amount`
    function withdraw(uint256 amount) external nonReentrant {
        address[] memory depositors_ = accountToPendingDepositors[msg.sender].values();
        uint256 remainder = amount;

        for (uint256 i = 0; i < depositors_.length && remainder > 0; i++) {
            MidasDepositor depositor = MidasDepositor(depositors_[i]);
            uint256 claimable = depositor.claimableTokenOutAmount();

            if (remainder < claimable) {
                depositor.withdraw(remainder);
                remainder = 0;
                break;
            }

            if (claimable > 0) {
                depositor.withdraw(claimable);
                remainder -= claimable;
            }

            if (depositor.pendingTokenOutAmount() == 0) {
                accountToPendingDepositors[msg.sender].remove(address(depositor));
            }
        }

        if (remainder > 0) revert InsufficientBalanceException();
    }

    /// @notice Withdraws mToken from a specific depositor
    /// @param depositor The depositor to withdraw from
    /// @param amount The amount to withdraw
    /// @dev Can be used to withdraw from a depositor that no longer counts as collateral,
    ///      if there are funds stranded on it
    function withdrawFromDepositor(address depositor, uint256 amount) external nonReentrant {
        if (!accountToDepositors[msg.sender].contains(depositor)) {
            revert DepositorNotOwnedByAccountException();
        }

        MidasDepositor(depositor).withdraw(amount);

        if (
            MidasDepositor(depositor).pendingTokenOutAmount() == 0
                && MidasDepositor(depositor).claimableTokenOutAmount() == 0
        ) {
            accountToPendingDepositors[msg.sender].remove(depositor);
        }
    }

    /// @notice Transfers a depositor to a new account
    /// @param depositor The depositor to transfer
    /// @param newAccount The new account to transfer the depositor to
    /// @dev Can only be used when account transfers are unlocked for a specific account - usually during liquidations
    /// @dev The depositor is removed forever from pending depositors, which means it can only be transferred once
    function transferDepositor(address depositor, address newAccount) external nonReentrant onlyEligibleAccount {
        if (
            newAccount == msg.sender || newAccount == address(0)
                || !accountToPendingDepositors[msg.sender].contains(depositor)
                || !IMidasTransferMaster(transferMaster).isTransferAllowed(msg.sender)
        ) {
            revert DepositorTransferNotAllowedException();
        }

        if (!_isGreenlistedIfRequired(newAccount)) revert NewAccountNotGreenlistedException();

        accountToDepositors[msg.sender].remove(depositor);
        accountToPendingDepositors[msg.sender].remove(depositor);

        accountToDepositors[newAccount].add(depositor);

        MidasDepositor(depositor).setAccount(newAccount);
    }

    /// @notice Gives an account a greenlisted role
    function receiveGreenlist() external nonReentrant onlyEligibleAccount {
        if (mode == MidasMode.Permissionless) {
            revert GreenlistRequestedInNonPermissionedModeException();
        }

        _grantGreenlistIfRequired(msg.sender);
    }

    /// @notice Returns the pending and claimable amounts of mToken for an account
    function pendingAndClaimableTokenOutAmounts(address account)
        external
        view
        returns (uint256 pendingAmount, uint256 claimableAmount)
    {
        address[] memory depositors_ = accountToPendingDepositors[account].values();
        for (uint256 i = 0; i < depositors_.length; ++i) {
            pendingAmount += MidasDepositor(depositors_[i]).pendingTokenOutAmount();
            claimableAmount += MidasDepositor(depositors_[i]).claimableTokenOutAmount();
        }
    }

    /// @notice Returns the pending depositors for an account
    function pendingDepositors(address account) external view returns (address[] memory) {
        return accountToPendingDepositors[account].values();
    }

    /// @notice Returns all depositors for an account
    function depositors(address account) external view returns (address[] memory) {
        return accountToDepositors[account].values();
    }

    /// @notice Returns whether a credit account owner satisfies the greenlist requirement, and the mToken address
    function isEligibleAccountOwner(address account) external view returns (bool, address) {
        return (_isGreenlistedIfRequired(account), mToken);
    }

    /// @notice Whether `account` is eligible to interact with the gateway
    function isAccountEligible(address account) public view override(CACheckerTrait, ICAChecker) returns (bool) {
        if (!super.isAccountEligible(account)) return false;

        (,,,,,,, address borrower) =
            ICreditManagerV3(ICreditAccountV3(account).creditManager()).creditAccountInfo(account);
        return _isGreenlistedIfRequired(borrower);
    }

    /// @dev Deploys a fresh depositor clone for `account` and registers it in both sets
    function _makeNewDepositorForAccount(address account) internal returns (address depositor) {
        if (accountToPendingDepositors[account].length() >= MAX_PENDING_DEPOSITORS_PER_ACCOUNT) {
            revert MaxPendingDepositorsPerAccountException();
        }

        depositor = Clones.clone(masterDepositor);
        MidasDepositor(depositor).setAccount(account);

        accountToDepositors[account].add(depositor);
        accountToPendingDepositors[account].add(depositor);
        _grantGreenlistIfRequired(depositor);
    }

    /// @dev Whether `account` satisfies the gateway's greenlist requirement
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
