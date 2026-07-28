// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IMidasIssuanceVault} from "./interfaces/external/IMidasIssuanceVault.sol";
import {IMidasRedemptionVault} from "./interfaces/external/IMidasRedemptionVault.sol";

import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

/// @title Midas swapper
/// @notice Reusable helper that performs instant Midas issuance/redemption on behalf of a single credit account
/// @dev Created as an EIP-1167 clone by `MidasGateway`. All mutating entrypoints are gateway-only;
/// @dev Some Midas mTokens may have unusual logic, such as deposits / redemptions being partially
///      fulfilled as an airdrop. In order to attribute the airdropped amount correctly, each gateway user
///      has its own connected swapper contract.
contract MidasSwapper {
    using SafeERC20 for IERC20;

    /// @notice Thrown when attempting to call a function from a caller other than the gateway
    error CallerNotGatewayException();

    /// @notice Thrown when attempting to withdraw more tokens than the swapper has
    error InsufficientBalanceException();

    /// @notice The account connected to this swapper
    address public account;

    /// @notice The gateway that owns this swapper
    address public immutable gateway;

    /// @notice The mToken issuance vault
    address public immutable midasIssuanceVault;

    /// @notice The mToken redemption vault
    address public immutable midasRedemptionVault;

    /// @notice Address of the mToken
    address public immutable mToken;

    /// @notice Address of the quote token used for issuance and redemption
    address public immutable quoteToken;

    modifier gatewayOnly() {
        if (msg.sender != gateway) revert CallerNotGatewayException();
        _;
    }

    /// @notice Constructor
    /// @param _midasIssuanceVault Address of the Midas Issuance Vault
    /// @param _midasRedemptionVault Address of the Midas Redemption Vault
    /// @param _quoteToken Address of the quote token used for issuance and redemption
    constructor(address _midasIssuanceVault, address _midasRedemptionVault, address _quoteToken) {
        gateway = msg.sender;
        midasIssuanceVault = _midasIssuanceVault;
        midasRedemptionVault = _midasRedemptionVault;
        mToken = IMidasRedemptionVault(_midasRedemptionVault).mToken();
        quoteToken = _quoteToken;
    }

    /// @notice Sets the account for this swapper
    function setAccount(address _account) external gatewayOnly {
        account = _account;
    }

    /// @notice Performs instant issuance of mToken for quote token already held by this swapper
    /// @param minReceiveAmount Minimum amount of mToken to receive
    /// @param referrerId Referrer ID
    function depositInstant(uint256 amountToken, uint256 minReceiveAmount, bytes32 referrerId) external gatewayOnly {
        IERC20(quoteToken).forceApprove(midasIssuanceVault, amountToken);
        IMidasIssuanceVault(midasIssuanceVault)
            .depositInstant(quoteToken, _convertToE18(amountToken), minReceiveAmount, referrerId);

        _sweepToken(quoteToken);
        _sweepToken(mToken);
    }

    /// @notice Performs instant redemption of mToken for quote token already held by this swapper
    /// @param minReceiveAmount Minimum amount of quote token to receive
    function redeemInstant(uint256 amountMTokenIn, uint256 minReceiveAmount) external gatewayOnly {
        IERC20(mToken).forceApprove(midasRedemptionVault, amountMTokenIn);
        IMidasRedemptionVault(midasRedemptionVault)
            .redeemInstant(quoteToken, amountMTokenIn, _convertToE18(minReceiveAmount));

        _sweepToken(quoteToken);
        _sweepToken(mToken);
    }

    /// @notice Sweeps a token held by this swapper to the connected account
    /// @param token Token to sweep
    function sweepToken(address token) external gatewayOnly {
        _sweepToken(token);
    }

    /// @dev Sweeps a token held by this swapper to the connected account
    function _sweepToken(address token) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(account, balance);
        }
    }

    /// @dev Converts the token amount to 18 decimals, which is accepted by Midas
    function _convertToE18(uint256 amount) internal view returns (uint256) {
        uint256 tokenUnit = 10 ** IERC20Metadata(quoteToken).decimals();
        return tokenUnit == WAD ? amount : amount * WAD / tokenUnit;
    }
}
