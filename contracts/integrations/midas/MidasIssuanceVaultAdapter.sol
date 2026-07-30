// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY, WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {TokenNotAllowedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {AbstractAdapter} from "../common/AbstractAdapter.sol";

import {IMidasIssuanceVault} from "./interfaces/external/IMidasIssuanceVault.sol";
import {IMidasIssuanceVaultAdapter} from "./interfaces/IMidasIssuanceVaultAdapter.sol";

/// @title Midas Issuance Vault adapter
/// @notice Allows Credit Accounts to perform instant Midas issuance directly against the issuance vault
contract MidasIssuanceVaultAdapter is AbstractAdapter, IMidasIssuanceVaultAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::MIDAS_ISSUANCE_VAULT";
    uint256 public constant override version = 3_11;

    /// @notice mToken
    address public immutable override mToken;

    /// @notice Issuance vault address (same as the adapter's target contract)
    address public immutable override issuanceVault;

    /// @notice Referrer ID used for issuances
    bytes32 public immutable override referrerId;

    /// @dev Set of allowed input tokens
    EnumerableSet.AddressSet internal _supportedInputTokens;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _issuanceVault Midas issuance vault address
    /// @param _referrerId Referrer ID to use for all issuances
    constructor(address _creditManager, address _issuanceVault, bytes32 _referrerId)
        AbstractAdapter(_creditManager, _issuanceVault)
    {
        issuanceVault = _issuanceVault;
        mToken = IMidasIssuanceVault(_issuanceVault).mToken();
        referrerId = _referrerId;

        _getMaskOrRevert(mToken);
    }

    /// @notice Deposits specified amount of an allowed input token for mToken
    /// @param tokenIn Input token to deposit
    /// @param amountToken Amount of input token to deposit
    /// @param minReceiveAmount Minimum amount of mToken to receive
    function depositInstant(address tokenIn, uint256 amountToken, uint256 minReceiveAmount, bytes32)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        _depositInstant(tokenIn, amountToken, minReceiveAmount);
        return false;
    }

    /// @notice Deposits entire balance of an allowed input token, except the specified amount
    /// @param tokenIn Input token to deposit
    /// @param leftoverAmount Amount of input token to keep in the account
    /// @param rateMinRAY Minimum exchange rate from input token to mToken (in RAY format)
    function depositInstantDiff(address tokenIn, uint256 leftoverAmount, uint256 rateMinRAY)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
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

    /// @dev Internal implementation of `depositInstant`
    function _depositInstant(address tokenIn, uint256 amountToken, uint256 minReceiveAmount) internal {
        if (!_supportedInputTokens.contains(tokenIn)) revert TokenNotAllowedException();

        _executeSwapSafeApprove(
            tokenIn,
            abi.encodeCall(
                IMidasIssuanceVault.depositInstant,
                (tokenIn, _convertToE18(tokenIn, amountToken), minReceiveAmount, referrerId)
            )
        );
    }

    /// @dev Converts the token amount to 18 decimals, which is accepted by Midas
    function _convertToE18(address token, uint256 amount) internal view returns (uint256) {
        uint256 tokenUnit = 10 ** IERC20Metadata(token).decimals();
        return tokenUnit == WAD ? amount : amount * WAD / tokenUnit;
    }

    // ---- //
    // DATA //
    // ---- //

    /// @notice Returns whether `token` is allowed as an input token
    function isInputTokenAllowed(address token) public view override returns (bool) {
        return _supportedInputTokens.contains(token);
    }

    /// @notice Returns the list of allowed input tokens
    function supportedInputTokens() public view override returns (address[] memory) {
        return _supportedInputTokens.values();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData =
            abi.encode(creditManager, targetContract, issuanceVault, mToken, referrerId, supportedInputTokens());
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Sets allowed status for a batch of input tokens
    /// @param tokens Tokens to update
    /// @param statuses Parallel array of allowed flags
    function setInputTokenStatusBatch(address[] calldata tokens, bool[] calldata statuses)
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
                _supportedInputTokens.add(token);
            } else {
                _supportedInputTokens.remove(token);
            }
            emit SetInputTokenStatus(token, statuses[i]);
        }
    }
}
