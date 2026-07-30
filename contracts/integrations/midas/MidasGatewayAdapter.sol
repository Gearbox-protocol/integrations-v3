// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {AbstractAdapter} from "../common/AbstractAdapter.sol";

import {IMidasGateway} from "./interfaces/IMidasGateway.sol";
import {IMidasGatewayAdapter} from "./interfaces/IMidasGatewayAdapter.sol";

/// @title Midas Gateway adapter
/// @notice Implements delayed-redemption logic for the Midas gateway and handles redemption phantom tokens
contract MidasGatewayAdapter is AbstractAdapter, IMidasGatewayAdapter {
    bytes32 public constant override contractType = "ADAPTER::MIDAS_GATEWAY";
    uint256 public constant override version = 3_11;

    /// @notice mToken
    address public immutable override mToken;

    /// @notice Gateway address (same as the adapter's target contract)
    address public immutable override gateway;

    /// @notice Quote token used for redemption
    address public immutable override quoteToken;

    /// @notice Redemption phantom token
    address public immutable override phantomToken;

    /// @dev Reverts when delayed-redemption functions are called without a phantom token configured
    modifier whenPhantomTokenSet() {
        if (phantomToken == address(0)) revert PhantomTokenNotSetException();
        _;
    }

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _gateway Midas gateway address
    constructor(address _creditManager, address _gateway) AbstractAdapter(_creditManager, _gateway) {
        gateway = _gateway;
        mToken = IMidasGateway(_gateway).mToken();
        quoteToken = IMidasGateway(_gateway).quoteToken();
        phantomToken = IMidasGateway(_gateway).phantomToken();

        _getMaskOrRevert(mToken);
        _getMaskOrRevert(quoteToken);
        if (phantomToken != address(0)) _getMaskOrRevert(phantomToken);
    }

    /// @notice Grants the greenlisted role to the credit account via the gateway
    function receiveGreenlist() external override creditFacadeOnly returns (bool) {
        _execute(abi.encodeCall(IMidasGateway.receiveGreenlist, ()));
        return false;
    }

    /// @notice Requests a redemption of mToken for quote token
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @dev Returns `true` to allow safe pricing for the withdrawal phantom token
    function redeemRequest(uint256 amountMTokenIn)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        _redeemRequest(amountMTokenIn, "");
        return true;
    }

    /// @inheritdoc IMidasGatewayAdapter
    function redeemRequest(uint256 amountMTokenIn, bytes calldata extraData)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        _redeemRequest(amountMTokenIn, extraData);
        return true;
    }

    /// @inheritdoc IMidasGatewayAdapter
    function redeemRequestDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
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
        whenPhantomTokenSet
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
        _executeSwapSafeApprove(mToken, abi.encodeCall(IMidasGateway.requestRedeem, (amountMTokenIn, extraData)));
    }

    /// @notice Withdraws redeemed tokens from the gateway
    /// @param amount Amount to withdraw
    function withdraw(uint256 amount) external override creditFacadeOnly whenPhantomTokenSet returns (bool) {
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
    function withdrawFromRedeemer(address redeemer, uint256 amount)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        _execute(abi.encodeCall(IMidasGateway.withdrawFromRedeemer, (redeemer, amount)));
        return false;
    }

    /// @notice Transfers a redeemer to a new account
    /// @param redeemer The redeemer to transfer
    /// @param newAccount The new account to transfer the redeemer to
    function transferRedeemer(address redeemer, address newAccount)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        _execute(abi.encodeCall(IMidasGateway.transferRedeemer, (redeemer, newAccount)));
        return false;
    }

    /// @notice Withdraws phantom token balance for its tracked output token
    /// @param token Phantom token address
    /// @param amount Amount to withdraw
    function withdrawPhantomToken(address token, uint256 amount)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        if (token != phantomToken) revert IncorrectStakedPhantomTokenException();

        _withdraw(amount);
        return false;
    }

    /// @notice Deposits phantom token (not implemented for redemptions)
    /// @dev Redemptions only support withdrawals, not deposits
    function depositPhantomToken(address, uint256)
        external
        view
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        revert NotImplementedException();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, gateway, mToken, quoteToken, phantomToken);
    }
}
