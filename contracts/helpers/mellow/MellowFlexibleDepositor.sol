// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IMellowDepositQueue} from "../../integrations/mellow/IMellowDepositQueue.sol";

/// @title MellowFlexibleDepositor
/// @notice As Mellow's deposit queue only accepts a single deposit per account, this contract is used
///         as a disposable proxy by the queue in order to make deposits on behalf of users. This also simplifies gateway logic,
///         as Mellow's own per-address deposit indexing can be used to track balances.
contract MellowFlexibleDepositor is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Thrown when attempting to claim when there are not enough shares to claim.
    error NotEnoughToClaimException();

    /// @notice Thrown when attempting to deposit when a deposit is already in progress.
    error DepositInProgressException();

    /// @notice Thrown when attempting to cancel a deposit when no deposit is in progress.
    error DepositNotInProgressException();

    /// @notice The account to make deposits on behalf of.
    address public immutable account;

    /// @notice Mellow deposit queue.
    address public immutable mellowDepositQueue;

    /// @notice The deposited asset.
    address public immutable asset;

    /// @notice The LP token of the vault.
    address public immutable vaultToken;

    constructor(address _mellowDepositQueue, address _asset, address _vaultToken, address _account) {
        _transferOwnership(msg.sender);
        mellowDepositQueue = _mellowDepositQueue;
        asset = _asset;
        vaultToken = _vaultToken;
        account = _account;
    }

    /// @notice Deposits assets on behalf of the account.
    /// @param assets The amount of assets to deposit.
    /// @param referral The referral address.
    function deposit(uint256 assets, address referral) external onlyOwner {
        if (_getPendingAssets() > 0) {
            revert DepositInProgressException();
        }

        IERC20(asset).forceApprove(mellowDepositQueue, assets);
        IMellowDepositQueue(mellowDepositQueue).deposit(uint224(assets), referral, new bytes32[](0));
    }

    /// @notice Cancels the deposit request.
    function cancelDepositRequest() external onlyOwner {
        uint256 pendingAssets = _getPendingAssets();

        if (pendingAssets == 0) {
            revert DepositNotInProgressException();
        }

        IMellowDepositQueue(mellowDepositQueue).cancelDepositRequest();
        IERC20(asset).safeTransfer(account, pendingAssets);
    }

    /// @notice Claims a specific amount from a matured deposit on behalf of the account.
    function claim(uint256 amount) external onlyOwner {
        (uint256 inQueue, uint256 onDepositor) = _getClaimableShares();

        if (inQueue != 0) {
            IMellowDepositQueue(mellowDepositQueue).claim(account);
            onDepositor = IERC20(vaultToken).balanceOf(address(this));
        }

        if (onDepositor < amount) {
            revert NotEnoughToClaimException();
        }

        IERC20(vaultToken).safeTransfer(account, amount);
    }

    /// @notice Returns the amount of assets pending for a deposit
    function getPendingAssets() external view returns (uint256) {
        return _getPendingAssets();
    }

    /// @notice Returns the amount of shares claimable from mature deposits
    function getClaimableShares() external view returns (uint256 shares) {
        (uint256 inQueue, uint256 onDepositor) = _getClaimableShares();
        return inQueue + onDepositor;
    }

    /// @dev Internal function to get the amount of assets pending for a deposit
    function _getPendingAssets() internal view returns (uint256) {
        (, uint256 assets) = IMellowDepositQueue(mellowDepositQueue).requestOf(address(this));
        return assets;
    }

    /// @dev Internal function to get the amount of shares claimable from mature deposits, still in the queue and already on the depositor
    function _getClaimableShares() internal view returns (uint256 inQueue, uint256 onDepositor) {
        return
            (IMellowDepositQueue(mellowDepositQueue).claimableOf(account), IERC20(vaultToken).balanceOf(address(this)));
    }
}
