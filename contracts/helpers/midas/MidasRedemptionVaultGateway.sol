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

import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

/// @title Midas Redemption Vault Gateway
/// @notice Gateway contract that manages redemptions from Midas vault on behalf of other accounts
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

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));

        IERC20(mToken).forceApprove(midasRedemptionVault, amountMTokenIn);
        IMidasRedemptionVault(midasRedemptionVault).redeemInstant(tokenOut, amountMTokenIn, minReceiveAmount);

        uint256 amount = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;

        IERC20(tokenOut).safeTransfer(msg.sender, amount);
    }

    /// @notice Requests a redemption of mToken for output token
    /// @param tokenOut Output token to receive
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @dev Stores the request ID and timestamp for tracking
    function requestRedeem(address tokenOut, uint256 amountMTokenIn) external nonReentrant {
        if (amountMTokenIn == 0) {
            revert ZeroAmountException();
        }

        if (pendingRedemptions[msg.sender].isActive) {
            revert HasPendingRedemptionException();
        }

        uint256 requestId = IMidasRedemptionVault(midasRedemptionVault).currentRequestId();

        IERC20(mToken).safeTransferFrom(msg.sender, address(this), amountMTokenIn);

        IERC20(mToken).forceApprove(midasRedemptionVault, amountMTokenIn);
        IMidasRedemptionVault(midasRedemptionVault).redeemRequest(tokenOut, amountMTokenIn);

        pendingRedemptions[msg.sender] = PendingRedemption({
            isActive: true,
            isManuallyCleared: false,
            requestId: requestId,
            timestamp: block.timestamp,
            remainder: 0
        });
    }

    /// @notice Withdraws tokens from a fulfilled redemption request
    /// @param amount Amount of output token to withdraw
    /// @dev Supports partial withdrawals by tracking remainder
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) {
            revert ZeroAmountException();
        }

        PendingRedemption memory pending = pendingRedemptions[msg.sender];

        if (!pending.isActive) {
            revert NoPendingRedemptionException();
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
            revert InvalidRequestException();
        }

        if (status != 1 && !pending.isManuallyCleared) {
            revert RedemptionNotFulfilledException();
        }

        uint256 availableAmount;

        if (pending.remainder > 0) {
            availableAmount = pending.remainder;
        } else {
            availableAmount = _calculateTokenOutAmount(amountMTokenIn, mTokenRate, tokenOutRate, tokenOut);
        }

        if (amount > availableAmount) {
            revert AmountExceedsAvailableException();
        }

        if (amount == availableAmount) {
            delete pendingRedemptions[msg.sender];
        } else {
            pendingRedemptions[msg.sender].remainder = availableAmount - amount;
        }

        IERC20(tokenOut).safeTransfer(msg.sender, amount);
    }

    /// @notice Returns the expected amount of output token for a account's pending redemption
    /// @param account account address to check
    /// @param tokenOut Output token to check
    /// @return Expected amount of output token, considering any partial withdrawals
    function pendingTokenOutAmount(address account, address tokenOut) external view returns (uint256) {
        PendingRedemption memory pending = pendingRedemptions[account];

        if (!pending.isActive) {
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

    /// @notice Clears a cancelled redemption request
    /// @param account account address to clear the request for
    /// @param amount Amount of output token to supply for the request. Must be at least the amount projected when the request was made.
    /// @dev If Midas rejects a request on accident, this function allows Midas or other interested party
    ///      to gracefully fulfill the request anyway, by manually supplying the required funds to the gateway.
    function clearCancelledRequest(address account, uint256 amount) external {
        PendingRedemption memory pending = pendingRedemptions[account];

        if (!pending.isActive) {
            revert NoPendingRedemptionException();
        }

        (, address tokenOut, uint8 status, uint256 amountMTokenIn, uint256 mTokenRate, uint256 tokenOutRate) =
            IMidasRedemptionVault(midasRedemptionVault).redeemRequests(pending.requestId);

        if (status != 2 || pending.isManuallyCleared) {
            revert RequestNotCancelledOrManuallyClearedException();
        }

        uint256 minAmount = _calculateTokenOutAmount(amountMTokenIn, mTokenRate, tokenOutRate, tokenOut);

        if (amount < minAmount) {
            revert AmountIsLessThanRequiredException();
        }

        IERC20(tokenOut).safeTransferFrom(msg.sender, address(this), amount);

        pendingRedemptions[account].isManuallyCleared = true;
        pendingRedemptions[account].remainder = amount;
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

        if (tokenUnit == WAD) return amount1e18;

        return amount1e18 * tokenUnit / WAD;
    }
}
