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

    /// @notice Address of the quote token redeemed from Midas
    address public immutable quoteToken;

    /// @notice The request ID for the redemption request
    uint256 public requestId;

    /// @notice Whether this redeemer was already used
    bool public alreadyRedeemed;

    /// @notice The timestamp when the redemption request was started
    uint256 public redemptionStartTimestamp;

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
    /// @param _quoteToken Address of the quote token redeemed from Midas
    constructor(address _midasRedemptionVault, address _quoteToken) {
        gateway = msg.sender;
        midasRedemptionVault = _midasRedemptionVault;
        mToken = IMidasRedemptionVault(_midasRedemptionVault).mToken();
        mTokenDataFeed = IMidasRedemptionVault(_midasRedemptionVault).mTokenDataFeed();
        quoteToken = _quoteToken;
    }

    /// @notice Sets the account for this redeemer
    function setAccount(address _account) external gatewayOnly {
        account = _account;
    }

    /// @notice Requests a redemption of mToken for quote token
    /// @param amountMTokenIn Amount of mToken to redeem
    function requestRedeem(uint256 amountMTokenIn) external gatewayOnly whenNotAlreadyRedeemed {
        IERC20(mToken).forceApprove(midasRedemptionVault, amountMTokenIn);
        requestId = IMidasRedemptionVault(midasRedemptionVault).redeemRequest(quoteToken, amountMTokenIn);
        alreadyRedeemed = true;
        redemptionStartTimestamp = block.timestamp;
    }

    /// @notice Withdraws tokens to the connected account
    /// @param amount Amount of quote token to withdraw
    function withdraw(uint256 amount) external gatewayOnly {
        if (IERC20(quoteToken).balanceOf(address(this)) < amount) revert InsufficientBalanceException();
        IERC20(quoteToken).safeTransfer(account, amount);
    }

    /// @notice Returns the expected amount of quote token for the pending redemption request
    function pendingTokenOutAmount() external view returns (uint256) {
        (,, uint8 status, uint256 amountMTokenIn,, uint256 tokenOutRate) =
            IMidasRedemptionVault(midasRedemptionVault).redeemRequests(requestId);

        if (status == 1 || isManuallyCleared) return 0;

        uint256 mTokenRate = IMidasDataFeed(mTokenDataFeed).getDataInBase18();

        return _calculateTokenOutAmount(amountMTokenIn, mTokenRate, tokenOutRate);
    }

    /// @notice Returns the amount of quote token that can be claimed
    function claimableTokenOutAmount() external view returns (uint256) {
        return IERC20(quoteToken).balanceOf(address(this));
    }

    /// @notice Clears a cancelled redemption request
    /// @param amount Amount of output token to supply for the request. Must be at least the amount projected when the request was made.
    /// @dev If Midas rejects a request on accident, this function allows Midas or other interested party
    ///      to gracefully fulfill the request anyway, by manually supplying the required funds to the gateway.
    function clearCancelledRequest(uint256 amount) external {
        (,, uint8 status, uint256 amountMTokenIn, uint256 mTokenRate, uint256 tokenOutRate) =
            IMidasRedemptionVault(midasRedemptionVault).redeemRequests(requestId);

        if (status != 2 || isManuallyCleared) {
            revert RequestNotCancelledOrManuallyClearedException();
        }

        uint256 minAmount = _calculateTokenOutAmount(amountMTokenIn, mTokenRate, tokenOutRate);

        if (amount < minAmount) {
            revert AmountIsLessThanRequiredException();
        }

        IERC20(quoteToken).safeTransferFrom(msg.sender, address(this), amount);

        isManuallyCleared = true;
    }

    /// @dev Calculates the output token amount from mToken amount and rates
    /// @param amountMTokenIn Amount of mToken
    /// @param mTokenRate Rate of mToken
    /// @param tokenOutRate Rate of quote token
    /// @return Amount of quote token in its native decimals
    function _calculateTokenOutAmount(uint256 amountMTokenIn, uint256 mTokenRate, uint256 tokenOutRate)
        internal
        view
        returns (uint256)
    {
        uint256 amount1e18 = (amountMTokenIn * mTokenRate) / tokenOutRate;

        uint256 tokenUnit = 10 ** IERC20Metadata(quoteToken).decimals();

        if (tokenUnit == WAD) return amount1e18;

        return amount1e18 * tokenUnit / WAD;
    }
}
