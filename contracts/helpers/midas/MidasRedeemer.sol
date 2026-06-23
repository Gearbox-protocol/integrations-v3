// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IMidasRedemptionVault} from "../../integrations/midas/IMidasRedemptionVault.sol";
import {IMidasDataFeed} from "../../integrations/midas/IMidasDataFeed.sol";

import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

contract MidasRedeemer {
    using SafeERC20 for IERC20;

    /// @notice Thrown when attempting to call a function from a caller other than the gateway.
    error CallerNotGatewayException();

    /// @notice Thrown when attempting to redeem from a used redeemer
    error AlreadyRedeemedException();

    /// @notice Thrown when attempting to withdraw more tokens than the redeemer has
    error InsufficientBalanceException();

    /// @notice Thrown when attempting to manually clear a non-eligible request
    error RequestNotCancelledOrManuallyClearedException();

    /// @notice Thrown when attempting to manually clear a request with an amount that is less than required
    error AmountIsLessThanRequiredException();

    /// @notice The account connected to this redeemer
    address public account;

    /// @notice The gateway that is using this redeemer
    address public immutable gateway;

    /// @notice The mToken redemption vault
    address public immutable midasRedemptionVault;

    /// @notice The data feed for the mToken
    address public immutable mTokenDataFeed;

    /// @notice Address of the mToken
    address public immutable mToken;

    /// @notice The request ID for the redemption request
    uint256 public requestId;

    /// @notice Whether this redeemer was already used
    bool public alreadyRedeemed;

    /// @notice Whether this redemption request was manually cleared
    bool public isManuallyCleared;

    modifier whenNotAlreadyRedeemed() {
        if (alreadyRedeemed) revert AlreadyRedeemedException();
        _;
    }

    modifier gatewayOnly() {
        if (msg.sender != gateway) revert CallerNotGatewayException();
        _;
    }

    /// @notice Constructor
    /// @param _midasRedemptionVault Address of the Midas Redemption Vault
    constructor(address _midasRedemptionVault) {
        gateway = msg.sender;
        midasRedemptionVault = _midasRedemptionVault;
        mToken = IMidasRedemptionVault(_midasRedemptionVault).mToken();
        mTokenDataFeed = IMidasRedemptionVault(_midasRedemptionVault).mTokenDataFeed();
    }

    /// @notice Sets the account for this redeemer
    function setAccount(address _account) external gatewayOnly {
        account = _account;
    }

    /// @notice Requests a redemption of mToken for output token
    /// @param tokenOut Output token to receive
    /// @param amountMTokenIn Amount of mToken to redeem
    function requestRedeem(address tokenOut, uint256 amountMTokenIn) external gatewayOnly whenNotAlreadyRedeemed {
        IERC20(mToken).forceApprove(midasRedemptionVault, amountMTokenIn);
        requestId = IMidasRedemptionVault(midasRedemptionVault).redeemRequest(tokenOut, amountMTokenIn);
        alreadyRedeemed = true;
    }

    /// @notice Withdraws tokens to the connected account
    /// @param tokenOut Output token to withdraw
    /// @param amount Amount of output token to withdraw
    function withdraw(address tokenOut, uint256 amount) external gatewayOnly {
        if (IERC20(tokenOut).balanceOf(address(this)) < amount) revert InsufficientBalanceException();
        IERC20(tokenOut).safeTransfer(account, amount);
    }

    /// @notice Returns the expected amount of output token for the pending redemption request
    /// @param tokenOut Output token to check
    function pendingTokenOutAmount(address tokenOut) external view returns (uint256) {
        (, address requestTokenOut, uint8 status, uint256 amountMTokenIn,, uint256 tokenOutRate) =
            IMidasRedemptionVault(midasRedemptionVault).redeemRequests(requestId);

        if (requestTokenOut != tokenOut || status == 1 || isManuallyCleared) return 0;

        uint256 mTokenRate = IMidasDataFeed(mTokenDataFeed).getDataInBase18();

        return _calculateTokenOutAmount(amountMTokenIn, mTokenRate, tokenOutRate, tokenOut);
    }

    /// @notice Returns the amount of output token that can be claimed
    /// @param tokenOut Output token to check
    function claimableTokenOutAmount(address tokenOut) external view returns (uint256) {
        return IERC20(tokenOut).balanceOf(address(this));
    }

    /// @notice Clears a cancelled redemption request
    /// @param amount Amount of output token to supply for the request. Must be at least the amount projected when the request was made.
    /// @dev If Midas rejects a request on accident, this function allows Midas or other interested party
    ///      to gracefully fulfill the request anyway, by manually supplying the required funds to the gateway.
    function clearCancelledRequest(uint256 amount) external {
        (, address tokenOut, uint8 status, uint256 amountMTokenIn, uint256 mTokenRate, uint256 tokenOutRate) =
            IMidasRedemptionVault(midasRedemptionVault).redeemRequests(requestId);

        if (status != 2 || isManuallyCleared) {
            revert RequestNotCancelledOrManuallyClearedException();
        }

        uint256 minAmount = _calculateTokenOutAmount(amountMTokenIn, mTokenRate, tokenOutRate, tokenOut);

        if (amount < minAmount) {
            revert AmountIsLessThanRequiredException();
        }

        IERC20(tokenOut).safeTransferFrom(msg.sender, address(this), amount);

        isManuallyCleared = true;
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
