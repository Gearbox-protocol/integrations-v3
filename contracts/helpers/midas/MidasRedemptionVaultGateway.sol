// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {ReentrancyGuardTrait} from "@gearbox-protocol/core-v3/contracts/traits/ReentrancyGuardTrait.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IMidasRedemptionVault} from "../../integrations/midas/IMidasRedemptionVault.sol";
import {IMidasRedemptionVaultGateway} from "../../interfaces/midas/IMidasRedemptionVaultGateway.sol";

/// @title Midas Redemption Vault Gateway
/// @notice Gateway contract that manages redemptions from Midas vault on behalf of users
/// @dev Stores pending redemption requests and handles partial withdrawals
contract MidasRedemptionVaultGateway is ReentrancyGuardTrait, IMidasRedemptionVaultGateway {
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::MIDAS_REDEMPTION_VAULT";
    uint256 public constant override version = 3_10;

    address public immutable midasRedemptionVault;
    address public immutable mToken;

    mapping(address => PendingRedemption) public pendingRedemptions;

    /// @notice Constructor
    /// @param _midasRedemptionVault Address of the Midas Redemption Vault
    constructor(address _midasRedemptionVault) {
        midasRedemptionVault = _midasRedemptionVault;
        mToken = IMidasRedemptionVault(_midasRedemptionVault).mToken();
    }

    /// @notice Performs instant redemption of mToken for output token
    /// @param tokenOut Output token to receive
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param minReceiveAmount Minimum amount of output token to receive
    /// @dev Transfers mToken from sender, redeems, and transfers output token back
    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount) external nonReentrant {
        IERC20(mToken).safeTransferFrom(msg.sender, address(this), amountMTokenIn);

        IERC20(mToken).forceApprove(midasRedemptionVault, amountMTokenIn);
        IMidasRedemptionVault(midasRedemptionVault).redeemInstant(tokenOut, amountMTokenIn, minReceiveAmount);

        uint256 balance = IERC20(tokenOut).balanceOf(address(this));
        IERC20(tokenOut).safeTransfer(msg.sender, balance);
    }

    /// @notice Requests a redemption of mToken for output token
    /// @param tokenOut Output token to receive
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @dev Stores the request ID and timestamp for tracking
    function requestRedeem(address tokenOut, uint256 amountMTokenIn) external nonReentrant {
        if (pendingRedemptions[msg.sender].requestId > 0) {
            revert("MidasRedemptionVaultGateway: user has a pending redemption");
        }

        uint256 requestId = IMidasRedemptionVault(midasRedemptionVault).currentRequestId();

        IERC20(mToken).safeTransferFrom(msg.sender, address(this), amountMTokenIn);

        IERC20(mToken).forceApprove(midasRedemptionVault, amountMTokenIn);
        IMidasRedemptionVault(midasRedemptionVault).redeemRequest(tokenOut, amountMTokenIn);

        pendingRedemptions[msg.sender] =
            PendingRedemption({requestId: requestId, timestamp: block.timestamp, remainder: 0});
    }

    /// @notice Withdraws tokens from a fulfilled redemption request
    /// @param amount Amount of output token to withdraw
    /// @dev Supports partial withdrawals by tracking remainder
    function withdraw(uint256 amount) external nonReentrant {
        PendingRedemption memory pending = pendingRedemptions[msg.sender];

        if (pending.requestId == 0) {
            revert("MidasRedemptionVaultGateway: user does not have a pending redemption");
        }

        (
            address sender,
            address tokenOut,
            uint8 status,
            uint256 amountMTokenIn,
            uint256 mTokenRate,
            uint256 tokenOutRate
        ) = IMidasRedemptionVault(midasRedemptionVault).redeemRequests(pending.requestId);

        if (sender != address(this)) {
            revert("MidasRedemptionVaultGateway: invalid request");
        }

        if (status != 1) {
            revert("MidasRedemptionVaultGateway: redemption not fulfilled");
        }

        uint256 availableAmount;

        if (pending.remainder > 0) {
            availableAmount = pending.remainder;
        } else {
            availableAmount = _calculateTokenOutAmount(amountMTokenIn, mTokenRate, tokenOutRate, tokenOut);
        }

        if (amount > availableAmount) {
            revert("MidasRedemptionVaultGateway: amount exceeds available");
        }

        if (amount == availableAmount) {
            delete pendingRedemptions[msg.sender];
        } else {
            pendingRedemptions[msg.sender].remainder = availableAmount - amount;
        }

        IERC20(tokenOut).safeTransfer(msg.sender, amount);
    }

    /// @notice Returns the expected amount of output token for a user's pending redemption
    /// @param user User address to check
    /// @param tokenOut Output token to check
    /// @return Expected amount of output token, considering any partial withdrawals
    function pendingTokenOutAmount(address user, address tokenOut) external view returns (uint256) {
        PendingRedemption memory pending = pendingRedemptions[user];

        if (pending.requestId == 0) {
            return 0;
        }

        (address sender, address requestTokenOut,, uint256 amountMTokenIn, uint256 mTokenRate, uint256 tokenOutRate) =
            IMidasRedemptionVault(midasRedemptionVault).redeemRequests(pending.requestId);

        if (sender != address(this) || requestTokenOut != tokenOut) {
            return 0;
        }

        if (pending.remainder > 0) {
            return pending.remainder;
        } else {
            return _calculateTokenOutAmount(amountMTokenIn, mTokenRate, tokenOutRate, tokenOut);
        }
    }

    /// @dev Calculates the output token amount from mToken amount and rates
    /// @param amountMTokenIn Amount of mToken
    /// @param mTokenRate Rate of mToken
    /// @param tokenOutRate Rate of output token
    /// @param tokenOut Address of output token
    /// @return Amount of output token in its native decimals
    function _calculateTokenOutAmount(
        uint256 amountMTokenIn,
        uint256 mTokenRate,
        uint256 tokenOutRate,
        address tokenOut
    ) internal view returns (uint256) {
        uint256 amount1e18 = (amountMTokenIn * mTokenRate) / tokenOutRate;

        uint256 tokenUnit = 10 ** IERC20Metadata(tokenOut).decimals();

        return amount1e18 * tokenUnit / 1e18;
    }
}
