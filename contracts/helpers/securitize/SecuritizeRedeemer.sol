// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ISecuritizeNAVProvider} from "../../integrations/securitize/ISecuritizeNAVProvider.sol";

/// @title SecuritizeRedeemer
/// @notice This contract directly performs redemptions on behalf of a credit account
contract SecuritizeRedeemer {
    using SafeERC20 for IERC20;

    /// @notice Thrown when attempting to call a function from a caller other than the gateway.
    error CallerNotGatewayException();

    /// @notice Thrown when attempting to redeem when the redeemer was already used
    error AlreadyRedeemedException();

    /// @notice The account to make withdrawals on behalf of.
    address public account;

    /// @notice The gateway that is using this redeemer
    address public immutable gateway;

    /// @notice The DS token to redeem
    address public immutable dsToken;

    /// @notice The decimals of the DS token
    uint256 public immutable dsTokenDecimalsMultiplier;

    /// @notice The stablecoin token to redeem
    address public immutable stableCoinToken;

    /// @notice The decimals of the stablecoin token
    uint256 public immutable stableCoinDecimalsMultiplier;

    /// @notice The redemption account to redeem to
    address public immutable redemptionAccount;

    /// @notice The NAV provider to get the NAV of the DS token
    address public immutable navProvider;

    /// @notice The amount of DS tokens redeemed
    uint256 public pendingDsTokenAmount;

    /// @notice Whether this redeemer was already used
    bool public alreadyRedeemed;

    /// @notice The NAV rate at beginning of redemption
    uint256 public startingNavRate;

    /// @notice The timestamp at beginning of redemption
    uint256 public startingTimestamp;

    modifier whenNotAlreadyRedeemed() {
        if (alreadyRedeemed) {
            revert AlreadyRedeemedException();
        }
        _;
    }

    modifier gatewayOnly() {
        if (msg.sender != gateway) {
            revert CallerNotGatewayException();
        }
        _;
    }

    constructor(address _dsToken, address _stableCoinToken, address _redemptionAccount, address _navProvider) {
        gateway = msg.sender;
        dsToken = _dsToken;
        stableCoinToken = _stableCoinToken;
        redemptionAccount = _redemptionAccount;
        navProvider = _navProvider;

        dsTokenDecimalsMultiplier = 10 ** IERC20Metadata(dsToken).decimals();
        stableCoinDecimalsMultiplier = 10 ** IERC20Metadata(stableCoinToken).decimals();
    }

    /// @notice Sets the account for this withdrawer
    function setAccount(address _account) external gatewayOnly {
        account = _account;
    }

    function redeem(uint256 dsTokenAmount) external gatewayOnly whenNotAlreadyRedeemed {
        IERC20(dsToken).safeTransfer(redemptionAccount, dsTokenAmount);
        startingTimestamp = block.timestamp;
        startingNavRate = ISecuritizeNAVProvider(navProvider).rate();
        pendingDsTokenAmount = dsTokenAmount;
        alreadyRedeemed = true;
    }

    function claim() external gatewayOnly {
        uint256 balance = IERC20(stableCoinToken).balanceOf(address(this));
        IERC20(stableCoinToken).safeTransfer(account, balance);
        pendingDsTokenAmount = 0;
    }

    /// @notice Gets the estimated redemption amount based on the current NAV
    function getCurrentRedemptionValue() public view returns (uint256) {
        uint256 currentNavRate = ISecuritizeNAVProvider(navProvider).rate();
        return pendingDsTokenAmount * stableCoinDecimalsMultiplier * currentNavRate
            / (dsTokenDecimalsMultiplier * dsTokenDecimalsMultiplier);
    }

    /// @notice Returns the minimal amount of stablecoins that is estimated to be received from redemption
    function getRedemptionAmount() external view returns (uint256) {
        uint256 maxRedemptionAmount = pendingDsTokenAmount * stableCoinDecimalsMultiplier * startingNavRate
            / (dsTokenDecimalsMultiplier * dsTokenDecimalsMultiplier);

        uint256 currentRedemptionAmount = getCurrentRedemptionValue();

        return currentRedemptionAmount > maxRedemptionAmount ? maxRedemptionAmount : currentRedemptionAmount;
    }
}
