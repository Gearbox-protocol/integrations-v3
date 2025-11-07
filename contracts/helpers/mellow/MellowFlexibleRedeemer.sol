// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IMellowRedeemQueue, Request} from "../../integrations/mellow/IMellowRedeemQueue.sol";

/// @title Mellow Flexible Vaults redeemer
/// @notice Having a separate redeemer address simplifies gateway logic,
///         as Mellow's own per-address redemption indexing can be used to track balances.
contract MellowFlexibleRedeemer is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Thrown when attempting to redeem when there are too many requests already, to avoid large
    ///         gas expenditure to retrieve pending/claimable amounts.
    error TooManyRequestsException();

    /// @notice Thrown when attempting to claim when there are not enough assets to claim.
    error NotEnoughToClaimException();

    /// @notice The account to make redemptions on behalf of.
    address public immutable account;

    /// @notice Mellow redeem queue.
    address public immutable mellowRedeemQueue;

    /// @notice The deposited asset.
    address public immutable asset;

    /// @notice The LP token of the vault.
    address public immutable vaultToken;

    constructor(address _mellowRedeemQueue, address _asset, address _vaultToken, address _account) {
        _transferOwnership(msg.sender);
        mellowRedeemQueue = _mellowRedeemQueue;
        asset = _asset;
        vaultToken = _vaultToken;
        account = _account;
    }

    /// @notice Initiates a redemption through the queue with exact amount of shares
    /// @param shares The amount of shares to redeem
    function redeem(uint256 shares) external onlyOwner {
        if (_getNumRequests() >= 5) {
            revert TooManyRequestsException();
        }

        IERC20(vaultToken).forceApprove(mellowRedeemQueue, shares);
        IMellowRedeemQueue(mellowRedeemQueue).redeem(shares);
    }

    /// @notice Claims a specific amount from mature redemptions
    function claim(uint256 amount) external onlyOwner {
        (uint256 inQueue, uint256 onRedeemer, uint32[] memory timestamps) = _getClaimableAssetsAndTimestamps();
        if (inQueue != 0) {
            IMellowRedeemQueue(mellowRedeemQueue).claim(address(this), timestamps);
            onRedeemer = IERC20(asset).balanceOf(address(this));
        }

        if (onRedeemer < amount) {
            revert NotEnoughToClaimException();
        }

        IERC20(asset).safeTransfer(account, amount);
    }

    /// @dev Internal function to get the number of existing requests for the account
    function _getNumRequests() internal view returns (uint256) {
        Request[] memory requests = IMellowRedeemQueue(mellowRedeemQueue).requestsOf(account, 0, type(uint256).max);
        return requests.length;
    }

    /// @notice Returns the amount of shares pending for a redemption
    function getPendingShares() external view returns (uint256 pendingShares) {
        Request[] memory requests = IMellowRedeemQueue(mellowRedeemQueue).requestsOf(account, 0, type(uint256).max);
        for (uint256 i = 0; i < requests.length; i++) {
            if (!requests[i].isClaimable) {
                pendingShares += requests[i].shares;
            }
        }
    }

    /// @notice Returns the amount of assets claimable from mature redemptions
    function getClaimableAssets() external view returns (uint256 claimableAssets) {
        (uint256 inQueue, uint256 onRedeemer,) = _getClaimableAssetsAndTimestamps();
        return inQueue + onRedeemer;
    }

    /// @dev Internal function to get the amount of assets claimable from mature redemptions, still in the queue and already on the redeemer. Also
    ///      returns the timestamps of active requests, which Mellow uses to index redemptions.
    function _getClaimableAssetsAndTimestamps()
        internal
        view
        returns (uint256 inQueue, uint256 onRedeemer, uint32[] memory timestamps)
    {
        Request[] memory requests = IMellowRedeemQueue(mellowRedeemQueue).requestsOf(account, 0, type(uint256).max);
        timestamps = new uint32[](requests.length);
        for (uint256 i = 0; i < requests.length; i++) {
            if (requests[i].isClaimable) {
                inQueue += requests[i].assets;
            }
            timestamps[i] = uint32(requests[i].timestamp);
        }

        onRedeemer = IERC20(asset).balanceOf(address(this));
    }
}
