// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {TokenNotAllowedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {AbstractAdapter} from "../common/AbstractAdapter.sol";

import {MidasDecimals} from "./MidasDecimals.sol";
import {IMidasRedemptionVault} from "./interfaces/external/IMidasRedemptionVault.sol";
import {IMidasRedemptionVaultAdapter} from "./interfaces/IMidasRedemptionVaultAdapter.sol";

/// @title Midas Redemption Vault adapter
/// @notice Allows Credit Accounts to perform instant Midas redemption directly against the redemption vault
/// @dev Instant redemption bypasses the gateway entirely — access is enforced by Midas itself, which requires the
///      credit account to be greenlisted for permissioned mTokens. Delayed redemptions go through the gateway.
contract MidasRedemptionVaultAdapter is AbstractAdapter, IMidasRedemptionVaultAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::MIDAS_REDEMPTION_VAULT";
    uint256 public constant override version = 3_11;

    /// @notice mToken
    address public immutable override mToken;

    /// @dev Set of allowed output tokens
    EnumerableSet.AddressSet internal _supportedOutputTokens;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _redemptionVault Midas redemption vault address
    constructor(address _creditManager, address _redemptionVault) AbstractAdapter(_creditManager, _redemptionVault) {
        mToken = IMidasRedemptionVault(_redemptionVault).mToken();

        _getMaskOrRevert(mToken);
    }

    /// @notice Instantly redeems mToken for an allowed output token
    /// @param tokenOut Output token to receive
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param minReceiveAmount Minimum amount of output token to receive
    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        _redeemInstant(tokenOut, amountMTokenIn, minReceiveAmount);
        return false;
    }

    /// @notice Instantly redeems the entire balance of mToken for an allowed output token, except the specified amount
    /// @param tokenOut Output token to receive
    /// @param leftoverAmount Amount of mToken to keep in the account
    /// @param rateMinRAY Minimum exchange rate from mToken to output token (in RAY format)
    function redeemInstantDiff(address tokenOut, uint256 leftoverAmount, uint256 rateMinRAY)
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
                uint256 minReceiveAmount = (amount * rateMinRAY) / RAY;
                _redeemInstant(tokenOut, amount, minReceiveAmount);
            }
        }
        return false;
    }

    function _redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount) internal {
        if (!_supportedOutputTokens.contains(tokenOut)) revert TokenNotAllowedException();

        _executeSwapSafeApprove(
            mToken,
            abi.encodeCall(
                IMidasRedemptionVault.redeemInstant,
                (tokenOut, amountMTokenIn, MidasDecimals.toE18(tokenOut, minReceiveAmount))
            )
        );
    }

    // ---- //
    // DATA //
    // ---- //

    /// @notice Returns whether `token` is allowed as an output token
    function isOutputTokenAllowed(address token) public view override returns (bool) {
        return _supportedOutputTokens.contains(token);
    }

    /// @notice Returns the list of allowed output tokens
    function supportedOutputTokens() public view override returns (address[] memory) {
        return _supportedOutputTokens.values();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, mToken, supportedOutputTokens());
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Sets allowed status for a batch of output tokens
    /// @param tokens Tokens to update
    /// @param statuses Parallel array of allowed flags
    function setOutputTokenStatusBatch(address[] calldata tokens, bool[] calldata statuses)
        external
        override
        configuratorOnly
    {
        uint256 len = tokens.length;
        if (len != statuses.length) revert IncorrectArrayLengthException();

        for (uint256 i; i < len; ++i) {
            address token = tokens[i];
            if (statuses[i]) {
                _getMaskOrRevert(token);
                _supportedOutputTokens.add(token);
            } else {
                _supportedOutputTokens.remove(token);
            }
            emit SetOutputTokenStatus(token, statuses[i]);
        }
    }
}
