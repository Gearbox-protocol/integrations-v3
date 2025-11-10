// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IKelpLRTWithdrawalManagerGateway} from "../../interfaces/kelp/IKelpLRTWithdrawalManagerGateway.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {KelpLRTWithdrawer} from "./KelpLRTWithdrawer.sol";

/// @title Kelp LRT Withdrawal Manager Gateway
/// @notice Acts as an intermediary between Gearbox Credit Acocunts and the Kelp LRT Withdrawal Manager to allow partial claiming of matured withdrawals.
contract KelpLRTWithdrawalManagerGateway is IKelpLRTWithdrawalManagerGateway {
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::KELP_WITHDRAWAL";
    uint256 public constant override version = 3_10;

    /// @notice The withdrawal manager contract
    address public immutable withdrawalManager;

    /// @notice The rsETH token
    address public immutable rsETH;

    /// @notice The WETH token
    address public immutable weth;

    /// @notice The master withdrawer contract
    address public immutable masterWithdrawer;

    /// @notice Mapping of accounts to corresponding withdrawer contracts,
    ///         which interact directly with the withdrawal manager
    mapping(address => address payable) public accountToWithdrawer;

    constructor(address _withdrawalManager, address _rsETH, address _weth) {
        withdrawalManager = _withdrawalManager;
        rsETH = _rsETH;
        weth = _weth;
        masterWithdrawer = address(new KelpLRTWithdrawer(withdrawalManager, rsETH, weth));
    }

    /// @notice Initiates a withdrawal for a specific amount of rsETH
    /// @param asset The asset to initiate the withdrawal for
    /// @param rsETHUnstaked The amount of rsETH to unstake
    /// @param referralId The referral ID
    function initiateWithdrawal(address asset, uint256 rsETHUnstaked, string calldata referralId) external {
        address payable withdrawer = _getWithdrawerForAccount(msg.sender);
        IERC20(rsETH).safeTransferFrom(msg.sender, withdrawer, rsETHUnstaked);
        KelpLRTWithdrawer(withdrawer).initiateWithdrawal(asset, rsETHUnstaked, referralId);
    }

    /// @notice Completes a withdrawal for a specific amount of assets
    /// @param asset The asset to complete the withdrawal for
    /// @param amount The amount of assets to complete the withdrawal for
    /// @param referralId The referral ID
    function completeWithdrawal(address asset, uint256 amount, string calldata referralId) external {
        address payable withdrawer = _getWithdrawerForAccount(msg.sender);
        KelpLRTWithdrawer(withdrawer).completeWithdrawal(asset, amount, referralId);
    }

    /// @notice Returns the amount of assets pending withdrawal
    /// @param asset The asset to get the pending withdrawal amount for
    /// @return The amount of assets pending withdrawal
    function getPendingAssetAmount(address account, address asset) external view returns (uint256) {
        address payable withdrawer = accountToWithdrawer[account];
        if (withdrawer == address(0)) {
            return 0;
        }
        return KelpLRTWithdrawer(withdrawer).getPendingAssetAmount(asset);
    }

    /// @notice Returns the amount of assets claimable from mature deposits
    /// @param asset The asset to get the claimable withdrawal amount for
    /// @return The amount of assets claimable from mature deposits
    function getClaimableAssetAmount(address account, address asset) external view returns (uint256) {
        address payable withdrawer = accountToWithdrawer[account];
        if (withdrawer == address(0)) {
            return 0;
        }
        return KelpLRTWithdrawer(withdrawer).getClaimableAssetAmount(asset);
    }

    /// @dev Internal function to get the withdrawer for an account, or create a new one if it doesn't exist
    /// @param account The account to get the withdrawer for
    /// @return The withdrawer for the account
    function _getWithdrawerForAccount(address account) internal returns (address payable) {
        address payable withdrawer = accountToWithdrawer[account];
        if (withdrawer == address(0)) {
            withdrawer = payable(Clones.clone(masterWithdrawer));
            KelpLRTWithdrawer(withdrawer).setAccount(account);
            accountToWithdrawer[account] = withdrawer;
        }
        return withdrawer;
    }
}
