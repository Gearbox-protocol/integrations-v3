// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IMellowFlexibleRedeemGateway} from "../../interfaces/mellow/IMellowFlexibleRedeemGateway.sol";
import {IMellowRedeemQueue} from "../../integrations/mellow/IMellowRedeemQueue.sol";
import {IMellowFlexibleVault} from "../../integrations/mellow/IMellowFlexibleVault.sol";
import {MellowFlexibleRedeemer} from "./MellowFlexibleRedeemer.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Mellow Flexible Vaults redemption gateway
/// @notice Acts as an intermediary between Gearbox Credit Acocunts and the Mellow redemption queue to allow partial claiming of matured redemptions.
contract MellowFlexibleRedeemGateway is IMellowFlexibleRedeemGateway {
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::MELLOW_REDEEM_QUEUE";
    uint256 public constant override version = 3_10;

    /// @notice The redemption queue contract
    address public immutable mellowRedeemQueue;

    /// @notice The asset redeemed from the vault through the queue
    address public immutable asset;

    /// @notice The vault token that is redeemed
    address public immutable vaultToken;

    /// @notice The master redeemer contract
    address public immutable masterRedeemer;

    /// @notice Mapping of accounts to corresponding redeemer contracts,
    ///         which interact directly with the queue
    mapping(address => address) public accountToRedeemer;

    constructor(address _mellowRedeemQueue) {
        mellowRedeemQueue = _mellowRedeemQueue;
        asset = IMellowRedeemQueue(mellowRedeemQueue).asset();
        vaultToken = IMellowFlexibleVault(IMellowRedeemQueue(mellowRedeemQueue).vault()).shareManager();
        masterRedeemer = address(new MellowFlexibleRedeemer(mellowRedeemQueue, asset, vaultToken));
    }

    /// @notice Initiates a redemption through the queue with exact amount of shares
    /// @param shares The amount of shares to redeem
    function redeem(uint256 shares) external {
        address redeemer = _getRedeemerForAccount(msg.sender);
        IERC20(vaultToken).safeTransferFrom(msg.sender, redeemer, shares);
        MellowFlexibleRedeemer(redeemer).redeem(shares);
    }

    /// @notice Claims a specific amount from mature redemptions
    function claim(uint256 amount) external {
        address redeemer = _getRedeemerForAccount(msg.sender);
        MellowFlexibleRedeemer(redeemer).claim(amount);
    }

    /// @notice Returns the amount of shares pending for a redemption
    function getPendingShares(address account) external view returns (uint256) {
        address redeemer = accountToRedeemer[account];
        if (redeemer == address(0)) {
            return 0;
        }
        return MellowFlexibleRedeemer(redeemer).getPendingShares();
    }

    /// @notice Returns the amount of assets claimable from mature redemptions
    function getClaimableAssets(address account) external view returns (uint256) {
        address redeemer = accountToRedeemer[account];
        if (redeemer == address(0)) {
            return 0;
        }
        return MellowFlexibleRedeemer(redeemer).getClaimableAssets();
    }

    /// @dev Internal function to get the redeemer contract for an account or create a new one if it doesn't exist
    function _getRedeemerForAccount(address account) internal returns (address) {
        address redeemer = accountToRedeemer[account];
        if (redeemer == address(0)) {
            redeemer = Clones.clone(masterRedeemer);
            MellowFlexibleRedeemer(redeemer).setAccount(account);
            accountToRedeemer[account] = redeemer;
        }
        return redeemer;
    }
}
