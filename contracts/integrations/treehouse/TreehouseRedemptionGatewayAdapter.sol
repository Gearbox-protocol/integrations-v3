// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";

import {AbstractAdapter} from "../common/AbstractAdapter.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {ITreehouseRedemptionGateway} from "./interfaces/ITreehouseRedemptionGateway.sol";
import {ITreehouseRedemptionGatewayAdapter} from "./interfaces/ITreehouseRedemptionGatewayAdapter.sol";

/// @title TreehouseRedemptionGatewayAdapter
/// @notice Implements logic for interacting with the TreehouseRedemptionGateway contract
contract TreehouseRedemptionGatewayAdapter is AbstractAdapter, ITreehouseRedemptionGatewayAdapter {
    bytes32 public constant override contractType = "ADAPTER::TREEHOUSE_GATEWAY";
    uint256 public constant override version = 3_10;

    address public immutable override tAsset;

    address public immutable override vaultUnderlying;

    address public immutable override phantomToken;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _targetContract Securitize redemption gateway
    constructor(address _creditManager, address _targetContract) AbstractAdapter(_creditManager, _targetContract) {
        tAsset = ITreehouseRedemptionGateway(_targetContract).tAsset();
        vaultUnderlying = ITreehouseRedemptionGateway(_targetContract).vaultUnderlying();
        phantomToken = ITreehouseRedemptionGateway(_targetContract).phantomToken();

        _getMaskOrRevert(tAsset);
        _getMaskOrRevert(vaultUnderlying);
        _getMaskOrRevert(phantomToken);
    }

    /// @notice Initiates a redemption for a specific tAsset amount
    /// @param shares The amount of tAsset to redeem
    /// @dev Returns `true` to allow safe pricing for the withdrawal phantom token
    function redeem(uint256 shares) external override creditFacadeOnly returns (bool) {
        _redeem(shares, "");
        return true;
    }

    /// @notice Initiates a redemption for a specific tAsset amount with extra data
    /// @param shares The amount of tAsset to redeem
    /// @param extraData Additional data to include in the redemption
    /// @dev Returns `true` to allow safe pricing for the withdrawal phantom token
    function redeem(uint256 shares, bytes calldata extraData) external override creditFacadeOnly returns (bool) {
        _redeem(shares, extraData);
        return true;
    }

    /// @notice Initiates a redemption for the entire balance of tAsset, except the specified amount
    /// @param leftoverShares The amount of tAsset to leave on the account
    /// @dev Returns `true` to allow safe pricing for the withdrawal phantom token
    function redeemDiff(uint256 leftoverShares) external override creditFacadeOnly returns (bool) {
        return _redeemDiff(leftoverShares, "");
    }

    /// @notice Initiates a redemption for the entire balance of tAsset, except the specified amount, with extra data
    /// @param leftoverShares The amount of tAsset to leave on the account
    /// @dev Returns `true` to allow safe pricing for the withdrawal phantom token
    function redeemDiff(uint256 leftoverShares, bytes calldata extraData)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        return _redeemDiff(leftoverShares, extraData);
    }

    /// @notice Internal implementation for `redeem`
    function _redeem(uint256 shares, bytes memory extraData) internal {
        _executeSwapSafeApprove(tAsset, abi.encodeCall(ITreehouseRedemptionGateway.redeem, (shares, extraData)));
    }

    /// @notice Internal implementation for `redeemDiff`
    function _redeemDiff(uint256 leftoverShares, bytes memory extraData) internal returns (bool) {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(tAsset).balanceOf(creditAccount);
        if (balance > leftoverShares) {
            unchecked {
                _redeem(balance - leftoverShares, extraData);
            }
            return true;
        }
        return false;
    }

    /// @notice Claims a mature redemption for a specific redeemer
    function finalizeRedeem(address redeemer) external override creditFacadeOnly returns (bool) {
        _execute(abi.encodeCall(ITreehouseRedemptionGateway.finalizeRedeem, (redeemer)));
        return true;
    }

    /// @notice Transfers a redeemer to a new account
    /// @param redeemer The redeemer to transfer
    /// @param newAccount The new account to transfer the redeemer to
    function transferRedeemer(address redeemer, address newAccount) external override creditFacadeOnly returns (bool) {
        _execute(abi.encodeCall(ITreehouseRedemptionGateway.transferRedeemer, (redeemer, newAccount)));
        return true;
    }

    function withdrawPhantomToken(address, uint256) external view override creditFacadeOnly returns (bool) {
        revert NotImplementedException();
    }

    function depositPhantomToken(address, uint256) external view override creditFacadeOnly returns (bool) {
        revert NotImplementedException();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, tAsset, vaultUnderlying, phantomToken);
    }
}
