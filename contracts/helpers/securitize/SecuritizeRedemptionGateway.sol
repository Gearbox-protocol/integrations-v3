// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ISecuritizeRedemptionGateway} from "../../interfaces/securitize/ISecuritizeRedemptionGateway.sol";
import {ISecuritizeWhitelister} from "../../integrations/securitize/ISecuritizeWhitelister.sol";
import {ISecuritizeGatewayTransferMaster} from "../../interfaces/securitize/ISecuritizeGatewayTransferMaster.sol";
import {SecuritizeRedeemer} from "./SecuritizeRedeemer.sol";

/// @title SecuritizeRedemptionGateway
/// @notice Allows Credit Accounts to redeem DS tokens to stablecoins using the EOA redemption flow
contract SecuritizeRedemptionGateway is ISecuritizeRedemptionGateway {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "GATEWAY::SECURITIZE_REDEMPTION";
    uint256 public constant override version = 3_10;

    address public immutable dsToken;

    address public immutable stableCoinToken;

    address public immutable redemptionAccount;

    address public immutable securitizeWhitelister;

    address public immutable transferMaster;

    address public immutable navProvider;

    address public immutable masterRedeemer;

    mapping(address => EnumerableSet.AddressSet) internal redeemersByAccount;

    mapping(address => EnumerableSet.AddressSet) internal unclaimedRedeemers;

    /// @notice Constructor
    constructor(
        address _dsToken,
        address _stableCoinToken,
        address _redemptionAccount,
        address _securitizeWhitelister,
        address _transferMaster,
        address _navProvider
    ) {
        dsToken = _dsToken;
        stableCoinToken = _stableCoinToken;
        redemptionAccount = _redemptionAccount;
        securitizeWhitelister = _securitizeWhitelister;
        transferMaster = _transferMaster;
        navProvider = _navProvider;
        masterRedeemer = address(new SecuritizeRedeemer(_dsToken, _stableCoinToken, _redemptionAccount, _navProvider));
    }

    /// @notice Redeem DS tokens for stablecoins
    /// @param dsTokenAmount The amount of DS tokens to redeem
    function redeem(uint256 dsTokenAmount) external {
        if (dsTokenAmount == 0) return;
        address redeemer = _makeNewRedeemerForAccount(msg.sender);
        IERC20(dsToken).safeTransferFrom(msg.sender, redeemer, dsTokenAmount);
        SecuritizeRedeemer(redeemer).redeem(dsTokenAmount);
    }

    function transferRedeemer(address redeemer, address newAccount) external {
        if (!redeemersByAccount[msg.sender].contains(redeemer)) {
            revert RedeemerNotOwnedByAccountException();
        }

        if (
            !ISecuritizeGatewayTransferMaster(transferMaster).isTransferAllowed()
                || !unclaimedRedeemers[msg.sender].contains(redeemer)
        ) {
            revert RedeemerTransferNotAllowedException();
        }

        redeemersByAccount[msg.sender].remove(redeemer);
        unclaimedRedeemers[msg.sender].remove(redeemer);
        redeemersByAccount[newAccount].add(redeemer);
        unclaimedRedeemers[newAccount].add(redeemer);

        SecuritizeRedeemer(redeemer).setAccount(newAccount);
    }

    /// @notice Claim stablecoins from redeemers
    /// @param redeemers The redeemers to claim from
    function claim(address[] calldata redeemers) external {
        for (uint256 i = 0; i < redeemers.length; i++) {
            if (!redeemersByAccount[msg.sender].contains(redeemers[i])) {
                revert RedeemerNotOwnedByAccountException();
            }

            SecuritizeRedeemer(redeemers[i]).claim();
            unclaimedRedeemers[msg.sender].remove(redeemers[i]);
        }
    }

    /// @notice Returns the amount of stablecoins that is estimated to be received from redemption
    /// @param account The account to get the redemption amount for
    function getRedemptionAmount(address account) external view returns (uint256 redemptionAmount) {
        address[] memory redeemers = unclaimedRedeemers[account].values();
        for (uint256 i = 0; i < redeemers.length; i++) {
            redemptionAmount += SecuritizeRedeemer(redeemers[i]).getRedemptionAmount();
        }
    }

    function getRedeemers(address account) external view returns (address[] memory) {
        return redeemersByAccount[account].values();
    }

    function getUnclaimedRedeemers(address account) external view returns (address[] memory) {
        return unclaimedRedeemers[account].values();
    }

    /// @dev Internal function to get the redeemer for an account, or create a new one if it doesn't exist
    /// @param account The account to get the redeemer for
    function _makeNewRedeemerForAccount(address account) internal returns (address redeemer) {
        redeemer = Clones.clone(masterRedeemer);
        SecuritizeRedeemer(redeemer).setAccount(account);
        ISecuritizeWhitelister(securitizeWhitelister).registerHelperAccount(account, redeemer, dsToken);

        if (unclaimedRedeemers[account].length() >= 10) {
            revert MaxUnclaimedRedeemersPerAccountException();
        }

        redeemersByAccount[account].add(redeemer);
        unclaimedRedeemers[account].add(redeemer);
    }
}
