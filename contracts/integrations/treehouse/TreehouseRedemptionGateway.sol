// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RedemptionLoggingTrait} from "../common/RedemptionLoggingTrait.sol";
import {
    ITreehouseRedemptionGateway,
    MAX_PENDING_REDEEMERS_PER_ACCOUNT
} from "./interfaces/ITreehouseRedemptionGateway.sol";
import {ITreehouseRedemptionV2} from "./interfaces/external/ITreehouseRedemptionV2.sol";
import {ITreehouseTransferMaster} from "./interfaces/ITreehouseTransferMaster.sol";
import {ITreehouseVault} from "./interfaces/external/ITreehouseVault.sol";
import {TreehouseRedeemer} from "./TreehouseRedeemer.sol";
import {TreehouseRedemptionPhantomToken} from "./TreehouseRedemptionPhantomToken.sol";

bytes32 constant SALT = keccak256("TreehouseRedemptionGateway");

/// @title TreehouseRedemptionGateway
/// @notice Allows Credit Accounts to redeem TAsset to underlying via Treehouse RedemptionV2 contract
contract TreehouseRedemptionGateway is RedemptionLoggingTrait, ITreehouseRedemptionGateway {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::TREEHOUSE_REDEMPTION";
    uint256 public constant override version = 1_00;

    address public immutable redemptionV2;

    address public immutable tAsset;

    address public immutable vaultUnderlying;

    address public immutable transferMaster;

    address public immutable masterRedeemer;

    address public immutable phantomToken;

    mapping(address => EnumerableSet.AddressSet) internal _accountToRedeemers;

    mapping(address => EnumerableSet.AddressSet) internal _accountToPendingRedeemers;

    constructor(address _redemptionV2, address _transferMaster, address _addressProvider)
        RedemptionLoggingTrait(_addressProvider)
    {
        redemptionV2 = _redemptionV2;
        tAsset = ITreehouseRedemptionV2(_redemptionV2).TASSET();
        address vault = ITreehouseRedemptionV2(_redemptionV2).VAULT();
        vaultUnderlying = ITreehouseVault(vault).getUnderlying();
        transferMaster = _transferMaster;
        masterRedeemer = address(new TreehouseRedeemer{salt: SALT}(redemptionV2, tAsset, vaultUnderlying));
        phantomToken = address(new TreehouseRedemptionPhantomToken{salt: SALT}(address(this), tAsset, vaultUnderlying));
    }

    function redeem(uint256 shares, bytes calldata extraData) external {
        if (shares == 0) return;
        address redeemer = _makeNewRedeemerForAccount(msg.sender);
        IERC20(tAsset).safeTransferFrom(msg.sender, redeemer, shares);
        TreehouseRedeemer(redeemer).redeem(shares);
        _logRedemption(msg.sender, redeemer, extraData);
    }

    function finalizeRedeem(address redeemer) external {
        if (!_accountToRedeemers[msg.sender].contains(redeemer)) revert RedeemerNotOwnedByAccountException();

        TreehouseRedeemer(redeemer).finalizeRedeem();

        _accountToPendingRedeemers[msg.sender].remove(redeemer);
    }

    function transferRedeemer(address redeemer, address newAccount) external {
        if (
            newAccount == msg.sender || newAccount == address(0)
                || !_accountToPendingRedeemers[msg.sender].contains(redeemer)
                || !ITreehouseTransferMaster(transferMaster).isTransferAllowed(msg.sender)
        ) {
            revert RedeemerTransferNotAllowedException();
        }

        _accountToRedeemers[msg.sender].remove(redeemer);
        _accountToPendingRedeemers[msg.sender].remove(redeemer);
        _accountToRedeemers[newAccount].add(redeemer);

        TreehouseRedeemer(redeemer).setAccount(newAccount);
    }

    function pendingAndClaimableAmounts(address account)
        external
        view
        returns (uint256 pendingAmount, uint256 claimableAmount)
    {
        address[] memory redeemers_ = _accountToPendingRedeemers[account].values();
        for (uint256 i = 0; i < redeemers_.length; ++i) {
            pendingAmount += TreehouseRedeemer(redeemers_[i]).pendingAmount();
            claimableAmount += TreehouseRedeemer(redeemers_[i]).claimableAmount();
        }
    }

    /// @notice Returns the pending redeemers for an account
    /// @param account The account to check
    /// @return The pending redeemers for the account
    function pendingRedeemers(address account) external view returns (address[] memory) {
        return _accountToPendingRedeemers[account].values();
    }

    /// @notice Returns all redeemers for an account
    /// @param account The account to check
    /// @return The redeemers for the account
    function redeemers(address account) external view returns (address[] memory) {
        return _accountToRedeemers[account].values();
    }

    /// @dev Deploys a fresh redeemer clone for `account` and registers it in both sets
    function _makeNewRedeemerForAccount(address account) internal returns (address redeemer) {
        if (_accountToPendingRedeemers[account].length() >= MAX_PENDING_REDEEMERS_PER_ACCOUNT) {
            revert MaxPendingRedeemersPerAccountException();
        }

        redeemer = Clones.clone(masterRedeemer);
        TreehouseRedeemer(redeemer).setAccount(account);

        _accountToRedeemers[account].add(redeemer);
        _accountToPendingRedeemers[account].add(redeemer);
    }
}
