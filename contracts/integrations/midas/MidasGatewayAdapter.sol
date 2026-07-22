// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {AbstractAdapter} from "../common/AbstractAdapter.sol";

import {IMidasGateway} from "./interfaces/IMidasGateway.sol";
import {IMidasGatewayAdapter} from "./interfaces/IMidasGatewayAdapter.sol";

/// @title Midas Gateway adapter
/// @notice Implements logic for interacting with the unified Midas gateway, which integrates both the
///         issuance and redemption vaults. Combines the scope of the standalone issuance and redemption
///         adapters and handles redemption phantom tokens.
contract MidasGatewayAdapter is AbstractAdapter, IMidasGatewayAdapter {
    bytes32 public constant override contractType = "ADAPTER::MIDAS_GATEWAY";
    uint256 public constant override version = 3_11;

    /// @notice mToken
    address public immutable override mToken;

    /// @notice Gateway address (same as the adapter's target contract)
    address public immutable override gateway;

    /// @notice Quote token used for issuance and redemption
    address public immutable override quoteToken;

    /// @notice Redemption phantom token
    address public immutable override phantomToken;

    /// @notice Referrer ID used for issuances
    bytes32 public immutable override referrerId;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _gateway Midas gateway address
    /// @param _referrerId Referrer ID to use for all issuances
    constructor(address _creditManager, address _gateway, bytes32 _referrerId)
        AbstractAdapter(_creditManager, _gateway)
    {
        gateway = _gateway;
        mToken = IMidasGateway(_gateway).mToken();
        quoteToken = IMidasGateway(_gateway).quoteToken();
        phantomToken = IMidasGateway(_gateway).phantomToken();

        _getMaskOrRevert(mToken);
        _getMaskOrRevert(quoteToken);
        // Checks that the phantom token is added to the CreditManager
        if (phantomToken != address(0)) _getMaskOrRevert(phantomToken);

        referrerId = _referrerId;
    }

    // -------- //
    // ISSUANCE //
    // -------- //

    /// @notice Deposits specified amount of quote token for mToken
    /// @param amountToken Amount of quote token to deposit
    /// @param minReceiveAmount Minimum amount of mToken to receive
    function depositInstant(uint256 amountToken, uint256 minReceiveAmount, bytes32)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        _depositInstant(amountToken, minReceiveAmount);
        return false;
    }

    /// @notice Deposits entire balance of quote token, except the specified amount
    /// @param leftoverAmount Amount of quote token to keep in the account
    /// @param rateMinRAY Minimum exchange rate from quote token to mToken (in RAY format)
    function depositInstantDiff(uint256 leftoverAmount, uint256 rateMinRAY)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        address creditAccount = _creditAccount();

        uint256 balance = IERC20(quoteToken).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                uint256 amount = balance - leftoverAmount;
                // TODO: why is it unchecked? Could amount*rateMinRAY overflow?
                uint256 minReceiveAmount = (amount * rateMinRAY) / RAY;
                _depositInstant(amount, minReceiveAmount);
            }
        }
        return false;
    }

    /// @dev Internal implementation of `depositInstant`.
    function _depositInstant(uint256 amountToken, uint256 minReceiveAmount) internal {
        _executeSwapSafeApprove(
            quoteToken, abi.encodeCall(IMidasGateway.depositInstant, (amountToken, minReceiveAmount, referrerId))
        );
    }

    // ---------- //
    // REDEMPTION //
    // ---------- //

    /// @notice Instantly redeems mToken for quote token
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param minReceiveAmount Minimum amount of quote token to receive
    function redeemInstant(uint256 amountMTokenIn, uint256 minReceiveAmount)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        _redeemInstant(amountMTokenIn, minReceiveAmount);
        return false;
    }

    /// @notice Instantly redeems the entire balance of mToken for quote token, except the specified amount
    /// @param leftoverAmount Amount of mToken to keep in the account
    /// @param rateMinRAY Minimum exchange rate from mToken to quote token (in RAY format)
    function redeemInstantDiff(uint256 leftoverAmount, uint256 rateMinRAY)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        address creditAccount = _creditAccount();

        uint256 balance = IERC20(mToken).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                uint256 amount = balance - leftoverAmount;

                /// TODO: why is it unchecked? Could amount*rateMinRAY overflow?
                uint256 minReceiveAmount = (amount * rateMinRAY) / RAY;
                _redeemInstant(amount, minReceiveAmount);
            }
        }
        return false;
    }

    /// @dev Internal implementation of `redeemInstant`
    function _redeemInstant(uint256 amountMTokenIn, uint256 minReceiveAmount) internal {
        _executeSwapSafeApprove(mToken, abi.encodeCall(IMidasGateway.redeemInstant, (amountMTokenIn, minReceiveAmount)));
    }

    /// @notice Requests a redemption of mToken for quote token
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @dev Returns `true` to allow safe pricing for the withdrawal phantom token
    function redeemRequest(uint256 amountMTokenIn) external override creditFacadeOnly returns (bool) {
        _redeemRequest(amountMTokenIn, "");
        return true;
    }

    /// @inheritdoc IMidasGatewayAdapter
    function redeemRequest(uint256 amountMTokenIn, bytes calldata extraData)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        _redeemRequest(amountMTokenIn, extraData);
        return true;
    }

    /// @inheritdoc IMidasGatewayAdapter
    function redeemRequestDiff(uint256 leftoverAmount) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(mToken).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                _redeemRequest(balance - leftoverAmount, "");
            }
            return true;
        }
        return false;
    }

    /// @inheritdoc IMidasGatewayAdapter
    function redeemRequestDiff(uint256 leftoverAmount, bytes calldata extraData)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(mToken).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                _redeemRequest(balance - leftoverAmount, extraData);
            }
            return true;
        }
        return false;
    }

    /// @dev Internal implementation of `redeemRequest`
    function _redeemRequest(uint256 amountMTokenIn, bytes memory extraData) internal {
        if (phantomToken == address(0)) revert PhantomTokenNotSetException();
        _executeSwapSafeApprove(mToken, abi.encodeCall(IMidasGateway.requestRedeem, (amountMTokenIn, extraData)));
    }

    /// @notice Withdraws redeemed tokens from the gateway
    /// @param amount Amount to withdraw
    function withdraw(uint256 amount) external override creditFacadeOnly returns (bool) {
        _withdraw(amount);
        return false;
    }

    /// @dev Internal implementation of `withdraw`
    function _withdraw(uint256 amount) internal {
        _execute(abi.encodeCall(IMidasGateway.withdraw, (amount)));
    }

    /// @notice Withdraws tokens from a specific redeemer
    /// @param redeemer The redeemer to withdraw from
    /// @param amount The amount to withdraw
    function withdrawFromRedeemer(address redeemer, uint256 amount) external override creditFacadeOnly returns (bool) {
        _execute(abi.encodeCall(IMidasGateway.withdrawFromRedeemer, (redeemer, amount)));
        return false;
    }

    // ----------------- //
    // TRANSFER REDEEMER //
    // ----------------- //

    /// @notice Transfers a redeemer to a new account
    /// @param redeemer The redeemer to transfer
    /// @param newAccount The new account to transfer the redeemer to
    function transferRedeemer(address redeemer, address newAccount) external override creditFacadeOnly returns (bool) {
        _execute(abi.encodeCall(IMidasGateway.transferRedeemer, (redeemer, newAccount)));
        return false;
    }

    // ------------- //
    // PHANTOM TOKEN //
    // ------------- //

    /// @notice Withdraws phantom token balance for its tracked output token
    /// @param token Phantom token address
    /// @param amount Amount to withdraw
    function withdrawPhantomToken(address token, uint256 amount) external override creditFacadeOnly returns (bool) {
        if (token != phantomToken) revert IncorrectStakedPhantomTokenException();

        _withdraw(amount);
        return false;
    }

    /// @notice Deposits phantom token (not implemented for redemptions)
    /// @dev Redemptions only support withdrawals, not deposits
    function depositPhantomToken(address, uint256) external view override creditFacadeOnly returns (bool) {
        revert NotImplementedException();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData =
            abi.encode(creditManager, targetContract, gateway, mToken, quoteToken, phantomToken, referrerId);
    }
}
