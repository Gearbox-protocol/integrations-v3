// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {WAD, RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IMidasIssuanceVault} from "../../integrations/midas/IMidasIssuanceVault.sol";
import {IMidasIssuanceVaultAdapter} from "../../interfaces/midas/IMidasIssuanceVaultAdapter.sol";

/// @title Midas Issuance Vault adapter
/// @notice Implements logic for interacting with the Midas Issuance Vault contract
contract MidasIssuanceVaultAdapter is AbstractAdapter, IMidasIssuanceVaultAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::MIDAS_ISSUANCE_VAULT";
    uint256 public constant override version = 3_10;

    /// @notice mToken
    address public immutable override mToken;

    /// @notice Referrer ID used for deposits
    bytes32 public immutable override referrerId;

    /// @dev Set of allowed input tokens for depositInstant
    EnumerableSet.AddressSet internal _allowedTokens;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _midasIssuanceVault Midas Issuance Vault address
    /// @param _referrerId Referrer ID to use for all deposits
    constructor(address _creditManager, address _midasIssuanceVault, bytes32 _referrerId)
        AbstractAdapter(_creditManager, _midasIssuanceVault)
    {
        mToken = IMidasIssuanceVault(_midasIssuanceVault).mToken();

        // We check that mToken is a valid collateral
        _getMaskOrRevert(mToken);

        referrerId = _referrerId;
    }

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
        if (!isTokenAllowed(tokenIn)) revert TokenNotAllowedException();

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
        if (!isTokenAllowed(tokenIn)) revert TokenNotAllowedException();

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
        _executeSwapSafeApprove(
            tokenIn,
            abi.encodeCall(
                IMidasIssuanceVault.depositInstant,
                (tokenIn, _convertToE18(amountToken, tokenIn), minReceiveAmount, referrerId)
            )
        );
    }

    /// @dev Converts the token amount to 18 decimals, which is accepted by Midas
    function _convertToE18(uint256 amount, address token) internal view returns (uint256) {
        uint256 tokenUnit = 10 ** IERC20Metadata(token).decimals();
        return amount * WAD / tokenUnit;
    }

    /// @notice Returns whether a token is allowed as input for depositInstant
    /// @param token Token address to check
    function isTokenAllowed(address token) public view override returns (bool) {
        return _allowedTokens.contains(token);
    }

    /// @notice Returns all allowed input tokens
    function allowedTokens() public view returns (address[] memory) {
        return _allowedTokens.values();
    }

    /// @notice Sets the allowed status for a batch of input tokens
    /// @param tokens Array of token addresses
    /// @param allowed Array of allowed statuses corresponding to each token
    /// @dev Can only be called by the configurator
    function setTokenAllowedStatusBatch(address[] calldata tokens, bool[] calldata allowed)
        external
        override
        configuratorOnly
    {
        uint256 len = tokens.length;
        if (len != allowed.length) revert IncorrectArrayLengthException();

        for (uint256 i; i < len; ++i) {
            if (allowed[i]) {
                // For each allowed token, we verify that it is a valid collateral,
                // as otherwise operations with unsupported tokens would be possible
                _getMaskOrRevert(tokens[i]);
                _allowedTokens.add(tokens[i]);
            } else {
                _allowedTokens.remove(tokens[i]);
            }
            emit SetTokenAllowedStatus(tokens[i], allowed[i]);
        }
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, mToken, referrerId, allowedTokens());
    }
}
