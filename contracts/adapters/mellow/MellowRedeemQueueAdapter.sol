// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {IMellowRedeemQueueAdapter} from "../../interfaces/mellow/IMellowRedeemQueueAdapter.sol";
import {IMellowFlexibleRedeemGateway} from "../../interfaces/mellow/IMellowFlexibleRedeemGateway.sol";
import {MellowFlexibleRedeemPhantomToken} from "../../helpers/mellow/MellowFlexbileRedeemPhantomToken.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Mellow Flexible vaults redemption queue adapter
/// @notice Implements logic allowing CAs to interact with the redemption queue of Mellow flexible vaults, allowing redemptions and matured redemption claiming.
contract MellowRedeemQueueAdapter is AbstractAdapter, IMellowRedeemQueueAdapter {
    bytes32 public constant override contractType = "ADAPTER::MELLOW_REDEEM_QUEUE";
    uint256 public constant override version = 3_10;

    /// @notice The vault token that is redeemed through the queue
    address public immutable vaultToken;

    /// @notice The phantom token representing the pending redemptions in the queue
    address public immutable phantomToken;

    /// @notice Constructor
    constructor(address _creditManager, address _redeemQueueGateway, address _phantomToken)
        AbstractAdapter(_creditManager, _redeemQueueGateway)
    {
        vaultToken = IMellowFlexibleRedeemGateway(_redeemQueueGateway).vaultToken();
        phantomToken = _phantomToken;

        if (MellowFlexibleRedeemPhantomToken(phantomToken).redeemQueueGateway() != _redeemQueueGateway) {
            revert InvalidRedeemQueueGatewayException();
        }

        _getMaskOrRevert(vaultToken);
        _getMaskOrRevert(phantomToken);
    }

    /// @notice Initiates a redemption through the queue with exact amount of shares
    /// @param shares The amount of shares to redeem
    /// @dev Returns true in order to price a new pending redemption using safe prices (to enforce a HF buffer on position opening)
    function redeem(uint256 shares) external creditFacadeOnly returns (bool) {
        _redeem(shares);
        return true;
    }

    /// @notice Initiates a redemption through the queue with the entire balance of the vault token, except the specified amount
    /// @param leftoverAmount The amount of vault tokens to leave on the credit account
    /// @dev Returns true in order to price a new pending redemption using safe prices (to enforce a HF buffer on position opening)
    function redeemDiff(uint256 leftoverAmount) external creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();

        uint256 amount = IERC20(vaultToken).balanceOf(creditAccount);

        if (amount <= leftoverAmount) return false;

        unchecked {
            amount = amount - leftoverAmount;
        }

        _redeem(amount);
        return true;
    }

    /// @dev Internal implementation for `redeem` and `redeemDiff`
    function _redeem(uint256 shares) internal {
        _executeSwapSafeApprove(vaultToken, abi.encodeCall(IMellowFlexibleRedeemGateway.redeem, (shares)));
    }

    /// @notice Claims a specific amount from mature redemptions
    function claim(uint256 amount) external creditFacadeOnly returns (bool) {
        _claim(amount);
        return false;
    }

    /// @dev Internal implementation for `claim`
    function _claim(uint256 amount) internal {
        _execute(abi.encodeCall(IMellowFlexibleRedeemGateway.claim, (amount)));
    }

    /// @notice Claims mature redemptions, represented by the corresponding phantom token
    function withdrawPhantomToken(address pt, uint256 amount) external creditFacadeOnly returns (bool) {
        if (pt != phantomToken) revert IncorrectStakedPhantomTokenException();
        _claim(amount);
        return false;
    }

    /// @dev Not implemented, as there is no way to go from the phantom token to the asset
    function depositPhantomToken(address, uint256) external view creditFacadeOnly returns (bool) {
        revert NotImplementedException();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, vaultToken, phantomToken);
    }
}
