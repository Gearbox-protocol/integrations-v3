// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {IMidasRedemptionVault} from "../../integrations/midas/IMidasRedemptionVault.sol";
import {IMidasRedemptionVaultAdapter} from "../../interfaces/midas/IMidasRedemptionVaultAdapter.sol";
import {IMidasRedemptionVaultGateway} from "../../interfaces/midas/IMidasRedemptionVaultGateway.sol";

/// @title Midas Redemption Vault adapter
/// @notice Implements logic for interacting with the Midas Redemption Vault through a gateway
contract MidasRedemptionVaultAdapter is AbstractAdapter, IMidasRedemptionVaultAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::MIDAS_REDEMPTION_VAULT";
    uint256 public constant override version = 3_10;

    /// @notice mToken
    address public immutable override mToken;

    /// @notice Gateway address
    address public immutable override gateway;

    /// @notice Mapping from phantom token to its tracked output token
    mapping(address => address) public phantomTokenToOutputToken;

    /// @dev Set of allowed output tokens for redemptions
    EnumerableSet.AddressSet internal _allowedTokens;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _gateway Midas Redemption Vault gateway address
    constructor(address _creditManager, address _gateway) AbstractAdapter(_creditManager, _gateway) {
        gateway = _gateway;
        mToken = IMidasRedemptionVaultGateway(_gateway).mToken();

        _getMaskOrRevert(mToken);
    }

    /// @notice Instantly redeems mToken for output token
    /// @param tokenOut Output token address
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @param minReceiveAmount Minimum amount of output token to receive
    /// @return Always returns false to indicate no approval cleanup needed
    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        if (!isTokenAllowed(tokenOut)) revert TokenNotAllowedException();

        _executeSwapSafeApprove(
            mToken,
            abi.encodeCall(IMidasRedemptionVaultGateway.redeemInstant, (tokenOut, amountMTokenIn, minReceiveAmount))
        );
        return false;
    }

    /// @notice Requests a redemption of mToken for output token
    /// @param tokenOut Output token address
    /// @param amountMTokenIn Amount of mToken to redeem
    /// @return Always returns true to indicate approval might be needed later
    function redeemRequest(address tokenOut, uint256 amountMTokenIn)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        if (!isTokenAllowed(tokenOut)) revert TokenNotAllowedException();

        _executeSwapSafeApprove(
            mToken, abi.encodeCall(IMidasRedemptionVaultGateway.requestRedeem, (tokenOut, amountMTokenIn))
        );
        return true;
    }

    /// @notice Withdraws redeemed tokens from the gateway
    /// @param amount Amount to withdraw
    /// @return Always returns false to indicate no approval cleanup needed
    function withdraw(uint256 amount) external override creditFacadeOnly returns (bool) {
        _withdraw(amount);
        return false;
    }

    /// @dev Internal implementation of withdraw
    function _withdraw(uint256 amount) internal {
        _execute(abi.encodeCall(IMidasRedemptionVaultGateway.withdraw, (amount)));
    }

    /// @notice Withdraws phantom token balance
    /// @param token Phantom token address
    /// @param amount Amount to withdraw
    /// @return Always returns false to indicate no approval cleanup needed
    function withdrawPhantomToken(address token, uint256 amount) external override creditFacadeOnly returns (bool) {
        if (phantomTokenToOutputToken[token] == address(0)) revert IncorrectStakedPhantomTokenException();
        _withdraw(amount);
        return false;
    }

    /// @notice Deposits phantom token (not implemented for redemption vaults)
    /// @return Never returns (always reverts)
    /// @dev Redemption vaults only support withdrawals, not deposits
    function depositPhantomToken(address, uint256) external pure override returns (bool) {
        revert NotImplementedException();
    }

    /// @notice Returns whether a token is allowed as output for redemptions
    /// @param token Token address to check
    /// @return True if token is allowed
    function isTokenAllowed(address token) public view override returns (bool) {
        return _allowedTokens.contains(token);
    }

    /// @notice Returns all allowed output tokens
    /// @return Array of allowed token addresses
    function allowedTokens() public view override returns (address[] memory) {
        return _allowedTokens.values();
    }

    /// @notice Sets the allowed status for a batch of output tokens
    /// @param configs Array of MidasAllowedTokenStatus structs
    /// @dev Can only be called by the configurator
    function setTokenAllowedStatusBatch(MidasAllowedTokenStatus[] calldata configs)
        external
        override
        configuratorOnly
    {
        uint256 len = configs.length;

        for (uint256 i; i < len; ++i) {
            MidasAllowedTokenStatus memory config = configs[i];

            if (config.allowed) {
                _getMaskOrRevert(config.token);
                _allowedTokens.add(config.token);

                if (config.phantomToken != address(0)) {
                    _getMaskOrRevert(config.phantomToken);
                    phantomTokenToOutputToken[config.phantomToken] = config.token;
                }
            } else {
                _allowedTokens.remove(config.token);

                // Remove any phantom token mappings for this token
                if (config.phantomToken != address(0)) {
                    delete phantomTokenToOutputToken[config.phantomToken];
                }
            }

            emit SetTokenAllowedStatus(config.token, config.phantomToken, config.allowed);
        }
    }

    /// @notice Serialized adapter parameters
    /// @return serializedData Encoded adapter configuration
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, gateway, mToken, allowedTokens());
    }
}
