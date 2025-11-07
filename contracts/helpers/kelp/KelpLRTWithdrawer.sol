// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "@gearbox-protocol/core-v3/contracts/interfaces/external/IWETH.sol";

import {IKelpLRTWithdrawalManager} from "../../integrations/kelp/IKelpLRTWithdrawalManager.sol";

address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

/// @title KelpLRTWithdrawer
/// @notice This contract simplifies gateway logic, as Kelp's own per-address withdrawal indexing can be used to track balances.
contract KelpLRTWithdrawer is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Thrown when attempting to withdraw when there are too many requests already, to avoid large
    ///         gas expenditure to retrieve pending/claimable amounts.
    error TooManyRequestsException();

    /// @notice Thrown when attempting to claim when there are not enough assets to claim.
    error NotEnoughToClaimException();

    /// @notice Thrown when receiving ETH from an address that is not the withdrawal manager.
    error IncorrectETHSenderException();

    /// @notice The account to make withdrawals on behalf of.
    address public immutable account;

    /// @notice Kelp LRT Withdrawal Manager.
    address public immutable withdrawalManager;

    /// @notice The rsETH token.
    address public immutable rsETH;

    /// @notice The WETH token.
    address public immutable weth;

    constructor(address _withdrawalManager, address _rsETH, address _weth, address _account) {
        _transferOwnership(msg.sender);
        withdrawalManager = _withdrawalManager;
        rsETH = _rsETH;
        account = _account;
        weth = _weth;
    }

    /// @notice Initiates a withdrawal for a specific amount of rsETH
    /// @param asset The asset to initiate the withdrawal for
    /// @param rsETHUnstaked The amount of rsETH to unstake
    /// @param referralId The referral ID
    function initiateWithdrawal(address asset, uint256 rsETHUnstaked, string calldata referralId) external onlyOwner {
        if (_getNumRequests(asset) >= 5) {
            revert TooManyRequestsException();
        }

        IERC20(asset).forceApprove(withdrawalManager, rsETHUnstaked);
        IKelpLRTWithdrawalManager(withdrawalManager).initiateWithdrawal(
            asset == weth ? ETH : asset, rsETHUnstaked, referralId
        );
    }

    /// @notice Completes a withdrawal for a specific amount of assets
    /// @param asset The asset to complete outstanding withdrawals for
    /// @param amount The amount of assets to transfer
    /// @param referralId The referral ID
    function completeWithdrawal(address asset, uint256 amount, string calldata referralId) external onlyOwner {
        (uint256 inWithdrawalManager, uint256 onWithdrawer, uint256 numClaimableRequests) = _getClaimableAssets(asset);
        if (inWithdrawalManager != 0) {
            for (uint256 i = 0; i < numClaimableRequests; i++) {
                IKelpLRTWithdrawalManager(withdrawalManager).completeWithdrawal(asset, referralId);
            }
            onWithdrawer = IERC20(asset).balanceOf(address(this));
        }

        if (onWithdrawer < amount) {
            revert NotEnoughToClaimException();
        }

        IERC20(asset).safeTransfer(account, amount);
    }

    /// @notice Returns the amount of assets pending withdrawal
    function getPendingAssetAmount(address asset) external view returns (uint256 pendingAssets) {
        uint256 numRequests = _getNumRequests(asset);
        uint256 nextLockedNonce = IKelpLRTWithdrawalManager(withdrawalManager).nextLockedNonce(asset);

        for (uint256 i = 0; i < numRequests; i++) {
            (, uint256 expectedAssetAmount,, uint256 userNonce) =
                IKelpLRTWithdrawalManager(withdrawalManager).getUserWithdrawalRequest(asset, account, i);

            if (userNonce >= nextLockedNonce) {
                pendingAssets += expectedAssetAmount;
            }
        }
    }

    /// @notice Returns the amount of shares claimable from mature deposits
    function getClaimableAssetAmount(address asset) external view returns (uint256 shares) {
        (uint256 inWithdrawalManager, uint256 onWithdrawer,) = _getClaimableAssets(asset);
        return inWithdrawalManager + onWithdrawer;
    }

    /// @dev Internal function to get the number of existing requests for an asset
    function _getNumRequests(address asset) internal view returns (uint256) {
        (uint128 start, uint128 end) = IKelpLRTWithdrawalManager(withdrawalManager).userAssociatedNonces(asset, account);
        return uint256(end - start);
    }

    /// @dev Internal function to get the amount of shares claimable from mature deposits,
    ///      still in the withdrawal manager and already on the withdrawer
    function _getClaimableAssets(address asset)
        internal
        view
        returns (uint256 inWithdrawalManager, uint256 onWithdrawer, uint256 numClaimableRequests)
    {
        onWithdrawer = IERC20(asset).balanceOf(address(this));

        uint256 numRequests = _getNumRequests(asset);
        uint256 nextLockedNonce = IKelpLRTWithdrawalManager(withdrawalManager).nextLockedNonce(asset);

        for (uint256 i = 0; i < numRequests; i++) {
            (, uint256 expectedAssetAmount,, uint256 userNonce) =
                IKelpLRTWithdrawalManager(withdrawalManager).getUserWithdrawalRequest(asset, account, i);

            if (userNonce < nextLockedNonce) {
                inWithdrawalManager += expectedAssetAmount;
                numClaimableRequests++;
            }
        }
    }

    receive() external payable {
        if (msg.sender != withdrawalManager) revert IncorrectETHSenderException();
        IWETH(weth).deposit{value: msg.value}();
    }
}
