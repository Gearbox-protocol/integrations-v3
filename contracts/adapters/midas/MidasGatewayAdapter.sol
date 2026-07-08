// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {WAD, RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IMidasGateway} from "../../interfaces/midas/IMidasGateway.sol";
import {IMidasGatewayAdapter} from "../../interfaces/midas/IMidasGatewayAdapter.sol";
import {MidasRedemptionVaultPhantomToken} from "../../helpers/midas/MidasRedemptionVaultPhantomToken.sol";

/// @title Midas Gateway adapter
/// @notice Implements logic for interacting with the unified Midas gateway, which integrates both the
///         issuance and redemption vaults. Combines the scope of the standalone issuance and redemption
///         adapters and handles redemption phantom tokens.
contract MidasGatewayAdapter is AbstractAdapter, IMidasGatewayAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::MIDAS_GATEWAY";
    uint256 public constant override version = 3_11;

    /// @notice mToken
    address public immutable override mToken;

    /// @notice Gateway address (same as the adapter's target contract)
    address public immutable override gateway;

    /// @notice Referrer ID used for issuances
    bytes32 public immutable override referrerId;

    /// @notice Mapping from phantom token to its tracked output token
    mapping(address => address) public override phantomTokenToOutputToken;

    /// @notice Mapping from output token to its tracked phantom token
    mapping(address => address) public override outputTokenToPhantomToken;

    /// @dev Set of allowed input tokens for issuances
    EnumerableSet.AddressSet internal _allowedInputTokens;

    /// @dev Set of allowed output tokens for redemptions
    EnumerableSet.AddressSet internal _allowedOutputTokens;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _gateway Midas gateway address
    /// @param _referrerId Referrer ID to use for all issuances
    constructor(address _creditManager, address _gateway, bytes32 _referrerId)
        AbstractAdapter(_creditManager, _gateway)
    {
        gateway = _gateway;
        mToken = IMidasGateway(_gateway).mToken();

        // We check that mToken is a valid collateral
        _getMaskOrRevert(mToken);

        referrerId = _referrerId;
    }

    // -------- //
    // ISSUANCE //
    // -------- //

    /// @notice Deposits specified amount of input token for mToken
    /// @param tokenIn Input token address
    /// @param amountToken Amount of input token to deposit
    /// @param minReceiveAmount Minimum amount of mToken to receive
    function depositInstant(address tokenIn, uint256 amountToken, uint256 minReceiveAmount, bytes32)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        if (!isInputTokenAllowed(tokenIn)) revert TokenNotAllowedException();

        _depositInstant(tokenIn, amountToken, minReceiveAmount);
        return false;
    }

    /// @notice Deposits entire balance of input token, except the specified amount
    /// @param tokenIn Input token address
    /// @param leftoverAmount Amount of input token to keep in the account
    /// @param rateMinRAY Minimum exchange rate from input token to mToken (in RAY format)
    function depositInstantDiff(address tokenIn, uint256 leftoverAmount, uint256 rateMinRAY)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        if (!isInputTokenAllowed(tokenIn)) revert TokenNotAllowedException();

        address creditAccount = _creditAccount();

        uint256 balance = IERC20(tokenIn).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                uint256 amount = balance - leftoverAmount;
                uint256 minReceiveAmount = (amount * rateMinRAY) / RAY;
                _depositInstant(tokenIn, amount, minReceiveAmount);
            }
        }
        return false;
    }

    /// @dev Internal implementation of `depositInstant`.
    function _depositInstant(address tokenIn, uint256 amountToken, uint256 minReceiveAmount) internal {
        _executeSwapSafeApprove(
            tokenIn, abi.encodeCall(IMidasGateway.depositInstant, (tokenIn, amountToken, minReceiveAmount, referrerId))
        );
    }

    // ---------- //
    // REDEMPTION //
    // ---------- //

    /// @notice Instantly redeems mToken for output token
    /// @param tokenOut Output token address
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param minReceiveAmount Minimum amount of output token to receive (in 18 decimals)
    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        if (!isOutputTokenAllowed(tokenOut)) revert TokenNotAllowedException();

        _redeemInstant(tokenOut, amountMTokenIn, minReceiveAmount);
        return false;
    }

    /// @notice Instantly redeems the entire balance of mToken for output token, except the specified amount
    /// @param tokenOut Output token address
    /// @param leftoverAmount Amount of mToken to keep in the account
    /// @param rateMinRAY Minimum exchange rate from mToken to output token (in RAY format)
    function redeemInstantDiff(address tokenOut, uint256 leftoverAmount, uint256 rateMinRAY)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        if (!isOutputTokenAllowed(tokenOut)) revert TokenNotAllowedException();

        address creditAccount = _creditAccount();

        uint256 balance = IERC20(mToken).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                uint256 amount = balance - leftoverAmount;
                uint256 minReceiveAmount = (amount * rateMinRAY) / RAY;
                _redeemInstant(tokenOut, amount, minReceiveAmount);
            }
        }
        return false;
    }

    /// @dev Internal implementation of `redeemInstant`
    function _redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount) internal {
        _executeSwapSafeApprove(
            mToken, abi.encodeCall(IMidasGateway.redeemInstant, (tokenOut, amountMTokenIn, minReceiveAmount))
        );
    }

    /// @notice Requests a redemption of mToken for output token
    /// @param tokenOut Output token address
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @dev Returns `true` to allow safe pricing for the withdrawal phantom token
    function redeemRequest(address tokenOut, uint256 amountMTokenIn) external override creditFacadeOnly returns (bool) {
        _validateRedeemRequestTokenOut(tokenOut);
        _redeemRequest(tokenOut, amountMTokenIn, "");
        return true;
    }

    /// @inheritdoc IMidasGatewayAdapter
    function redeemRequest(address tokenOut, uint256 amountMTokenIn, bytes calldata extraData)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        _validateRedeemRequestTokenOut(tokenOut);
        _redeemRequest(tokenOut, amountMTokenIn, extraData);
        return true;
    }

    /// @inheritdoc IMidasGatewayAdapter
    function redeemRequestDiff(address tokenOut, uint256 leftoverAmount)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        _validateRedeemRequestTokenOut(tokenOut);

        address creditAccount = _creditAccount();
        uint256 balance = IERC20(mToken).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                _redeemRequest(tokenOut, balance - leftoverAmount, "");
            }
            return true;
        }
        return false;
    }

    /// @inheritdoc IMidasGatewayAdapter
    function redeemRequestDiff(address tokenOut, uint256 leftoverAmount, bytes calldata extraData)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        _validateRedeemRequestTokenOut(tokenOut);

        address creditAccount = _creditAccount();
        uint256 balance = IERC20(mToken).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                _redeemRequest(tokenOut, balance - leftoverAmount, extraData);
            }
            return true;
        }
        return false;
    }

    /// @dev Internal implementation of `redeemRequest`
    function _redeemRequest(address tokenOut, uint256 amountMTokenIn, bytes memory extraData) internal {
        _executeSwapSafeApprove(
            mToken, abi.encodeCall(IMidasGateway.requestRedeem, (tokenOut, amountMTokenIn, extraData))
        );
    }

    /// @dev Validates that a token is allowed for redemption requests
    function _validateRedeemRequestTokenOut(address tokenOut) internal view {
        if (!isOutputTokenAllowed(tokenOut) || outputTokenToPhantomToken[tokenOut] == address(0)) {
            revert TokenNotAllowedException();
        }
    }

    /// @notice Withdraws redeemed tokens from the gateway
    /// @param tokenOut Output token to withdraw
    /// @param amount Amount to withdraw
    function withdraw(address tokenOut, uint256 amount) external override creditFacadeOnly returns (bool) {
        _withdraw(tokenOut, amount);
        return false;
    }

    /// @dev Internal implementation of `withdraw`
    function _withdraw(address tokenOut, uint256 amount) internal {
        _execute(abi.encodeCall(IMidasGateway.withdraw, (tokenOut, amount)));
    }

    /// @notice Withdraws tokens from a specific redeemer
    /// @param redeemer The redeemer to withdraw from
    /// @param tokenOut The token to withdraw
    /// @param amount The amount to withdraw
    function withdrawFromRedeemer(address redeemer, address tokenOut, uint256 amount)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        _execute(abi.encodeCall(IMidasGateway.withdrawFromRedeemer, (redeemer, tokenOut, amount)));
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
        address tokenOut = phantomTokenToOutputToken[token];
        if (tokenOut == address(0)) revert IncorrectStakedPhantomTokenException();

        _withdraw(tokenOut, amount);
        return false;
    }

    /// @notice Deposits phantom token (not implemented for redemptions)
    /// @dev Redemptions only support withdrawals, not deposits
    function depositPhantomToken(address, uint256) external view override creditFacadeOnly returns (bool) {
        revert NotImplementedException();
    }

    // ------- //
    // GETTERS //
    // ------- //

    /// @notice Returns whether a token is allowed as input for issuances
    function isInputTokenAllowed(address token) public view override returns (bool) {
        return _allowedInputTokens.contains(token);
    }

    /// @notice Returns all allowed input tokens
    function allowedInputTokens() public view override returns (address[] memory) {
        return _allowedInputTokens.values();
    }

    /// @notice Returns whether a token is allowed as output for redemptions
    function isOutputTokenAllowed(address token) public view override returns (bool) {
        return _allowedOutputTokens.contains(token);
    }

    /// @notice Returns all allowed output tokens
    function allowedOutputTokens() public view override returns (address[] memory) {
        return _allowedOutputTokens.values();
    }

    /// @notice Returns the list of phantom tokens associated to each allowed output token
    function allowedPhantomTokens() public view override returns (address[] memory) {
        address[] memory tokens = allowedOutputTokens();
        address[] memory phantomTokens = new address[](tokens.length);
        for (uint256 i; i < tokens.length; ++i) {
            phantomTokens[i] = outputTokenToPhantomToken[tokens[i]];
        }
        return phantomTokens;
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Sets the allowed status for a batch of input tokens
    /// @param tokens Array of token addresses
    /// @param allowed Array of allowed statuses corresponding to each token
    /// @dev Can only be called by the configurator
    function setInputTokenAllowedStatusBatch(address[] calldata tokens, bool[] calldata allowed)
        external
        override
        configuratorOnly
    {
        uint256 len = tokens.length;
        if (len != allowed.length) revert IncorrectArrayLengthException();

        for (uint256 i; i < len; ++i) {
            if (allowed[i]) {
                _getMaskOrRevert(tokens[i]);
                _allowedInputTokens.add(tokens[i]);
            } else {
                _allowedInputTokens.remove(tokens[i]);
            }
            emit SetInputTokenAllowedStatus(tokens[i], allowed[i]);
        }
    }

    /// @notice Sets the allowed status for a batch of output tokens
    /// @param configs Array of MidasAllowedTokenStatus structs
    /// @dev Can only be called by the configurator
    function setOutputTokenAllowedStatusBatch(MidasAllowedTokenStatus[] calldata configs)
        external
        override
        configuratorOnly
    {
        uint256 len = configs.length;

        for (uint256 i; i < len; ++i) {
            MidasAllowedTokenStatus memory config = configs[i];

            if (config.allowed) {
                _getMaskOrRevert(config.token);
                _allowedOutputTokens.add(config.token);

                if (config.phantomToken != address(0)) {
                    if (MidasRedemptionVaultPhantomToken(config.phantomToken).tokenOut() != config.token) {
                        revert PhantomTokenTokenOutMismatchException();
                    }
                    _getMaskOrRevert(config.phantomToken);
                    phantomTokenToOutputToken[config.phantomToken] = config.token;
                    outputTokenToPhantomToken[config.token] = config.phantomToken;
                }
            } else {
                _allowedOutputTokens.remove(config.token);

                address phantomToken = outputTokenToPhantomToken[config.token];

                if (phantomToken != address(0)) {
                    delete outputTokenToPhantomToken[config.token];
                    delete phantomTokenToOutputToken[phantomToken];
                }
            }

            emit SetOutputTokenAllowedStatus(config.token, config.phantomToken, config.allowed);
        }
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(
            creditManager,
            targetContract,
            gateway,
            mToken,
            referrerId,
            allowedInputTokens(),
            allowedOutputTokens(),
            allowedPhantomTokens()
        );
    }
}
