// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {IMellowDepositQueueAdapter} from "../../interfaces/mellow/IMellowDepositQueueAdapter.sol";
import {IMellowFlexibleDepositGateway} from "../../interfaces/mellow/IMellowFlexibleDepositGateway.sol";
import {MellowFlexibleDepositPhantomToken} from "../../helpers/mellow/MellowFlexibleDepositPhantomToken.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Mellow Flexible vaults deposit queue adapter
/// @notice Implements logic allowing CAs to interact with the deposit queue of Mellow flexible vaults, allowing deposits and matured deposit claiming.
contract MellowDepositQueueAdapter is AbstractAdapter, IMellowDepositQueueAdapter {
    bytes32 public constant override contractType = "ADAPTER::MELLOW_DEPOSIT_QUEUE";
    uint256 public constant override version = 3_10;

    /// @notice The asset deposited into the vault through the queue
    address public immutable asset;

    /// @notice The phantom token representing the pending deposits in the queue
    address public immutable phantomToken;

    /// @notice The referral address for the deposits
    address public immutable referral;

    /// @notice Constructor
    constructor(address _creditManager, address _depositQueueGateway, address _referral, address _phantomToken)
        AbstractAdapter(_creditManager, _depositQueueGateway)
    {
        asset = IMellowFlexibleDepositGateway(_depositQueueGateway).asset();
        phantomToken = _phantomToken;
        referral = _referral;

        if (MellowFlexibleDepositPhantomToken(phantomToken).depositQueueGateway() != _depositQueueGateway) {
            revert InvalidDepositQueueGatewayException();
        }

        _getMaskOrRevert(asset);
        _getMaskOrRevert(phantomToken);
    }

    /// @notice Initiates a deposit through the queue with exact amount of assets
    /// @param assets The amount of assets to deposit
    /// @dev `referral` and `merkleProof` are ignored, since the first is hard-coded on deployment, and the second
    ///      is on off-chain parameter that is not required
    /// @dev Returns true in order to price a new pending deposit using safe prices (to enforce a HF buffer on position opening)
    function deposit(uint256 assets, address, bytes32[] calldata) external creditFacadeOnly returns (bool) {
        _deposit(assets);
        return true;
    }

    /// @notice Initiates a deposit through the queue with the entire balance of the asset, except the specified amount
    /// @param leftoverAmount The amount of assets to leave on the credit account
    /// @dev Returns true in order to price a new pending deposit using safe prices (to enforce a HF buffer on position opening)
    function depositDiff(uint256 leftoverAmount) external creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();

        uint256 amount = IERC20(asset).balanceOf(creditAccount);

        if (amount <= leftoverAmount) return false;

        unchecked {
            amount = amount - leftoverAmount;
        }

        _deposit(amount);
        return true;
    }

    /// @dev Internal implementation for `deposit` and `depositDiff`
    function _deposit(uint256 assets) internal {
        _executeSwapSafeApprove(
            asset, abi.encodeCall(IMellowFlexibleDepositGateway.deposit, (assets, referral, new bytes32[](0)))
        );
    }

    /// @notice Cancels a pending deposit request
    function cancelDepositRequest() external creditFacadeOnly returns (bool) {
        _execute(abi.encodeCall(IMellowFlexibleDepositGateway.cancelDepositRequest, ()));
        return false;
    }

    /// @notice Claims a specific amount from mature deposits
    function claim(uint256 amount) external creditFacadeOnly returns (bool) {
        _claim(amount);
        return false;
    }

    /// @dev Internal implementation for `claim`
    function _claim(uint256 amount) internal {
        _execute(abi.encodeCall(IMellowFlexibleDepositGateway.claim, (amount)));
    }

    /// @notice Claims mature deposits, represented by the corresponding phantom token
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
        serializedData = abi.encode(creditManager, targetContract, asset, phantomToken, referral);
    }
}
