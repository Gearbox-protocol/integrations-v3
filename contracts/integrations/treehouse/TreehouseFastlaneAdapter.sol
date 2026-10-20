// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {AbstractAdapter} from "../common/AbstractAdapter.sol";

import {ITreehouseFastlane} from "./interfaces/external/ITreehouseFastlane.sol";
import {ITreehouseFastlaneAdapter} from "./interfaces/ITreehouseFastlaneAdapter.sol";

/// @title Treehouse Fastlane adapter
/// @notice Implements logic allowing CAs to perform immediate redemptions via Treehouse Fastlane
contract TreehouseFastlaneAdapter is AbstractAdapter, ITreehouseFastlaneAdapter {
    using SafeCast for uint256;

    bytes32 public constant override contractType = "ADAPTER::TREEHOUSE_FASTLANE";
    uint256 public constant override version = 3_10;

    /// @notice TAsset redeemed via Fastlane
    address public immutable tAsset;

    /// @notice Underlying returned from Fastlane
    address public immutable vaultUnderlying;

    constructor(address _creditManager, address _targetContract) AbstractAdapter(_creditManager, _targetContract) {
        tAsset = ITreehouseFastlane(_targetContract).TASSET();
        vaultUnderlying = ITreehouseFastlane(_targetContract).UNDERLYING();

        _getMaskOrRevert(tAsset);
        _getMaskOrRevert(vaultUnderlying);
    }

    /// @notice Redeem a given amount of shares from TAsset via Fastlane
    /// @param shares The amount of shares to redeem
    function redeemAndFinalize(uint256 shares) external override creditFacadeOnly returns (bool) {
        _redeemAndFinalize(shares);
        return false;
    }

    /// @notice Redeem the entire balance of shares from TAsset via Fastlane, except the specified amount
    /// @param leftoverShares The amount of shares to leave on the account
    function redeemAndFinalizeDiff(uint256 leftoverShares) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();

        uint256 shares = IERC20(tAsset).balanceOf(creditAccount);

        if (shares <= leftoverShares) return false;
        unchecked {
            shares -= leftoverShares;
        }

        _redeemAndFinalize(shares);
        return false;
    }

    /// @dev Internal implementation for `redeemAndFinalize`
    function _redeemAndFinalize(uint256 shares) internal {
        _executeSwapSafeApprove(tAsset, abi.encodeCall(ITreehouseFastlane.redeemAndFinalize, (shares.toUint96())));
    }

    function serialize() external view override returns (bytes memory) {
        return abi.encode(creditManager, targetContract, tAsset, vaultUnderlying);
    }
}
