// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {AbstractAdapter} from "../common/AbstractAdapter.sol";

import {ITreehouseRouter} from "./interfaces/external/ITreehouseRouter.sol";
import {ITreehouseRouterAdapter} from "./interfaces/ITreehouseRouterAdapter.sol";

/// @title Treehouse Router adapter
/// @notice Implements logic allowing CAs to perform deposits via Treehouse Router
contract TreehouseRouterAdapter is AbstractAdapter, ITreehouseRouterAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::TREEHOUSE_ROUTER";
    uint256 public constant override version = 3_10;

    EnumerableSet.AddressSet internal _allowedAssets;

    constructor(address _creditManager, address _router) AbstractAdapter(_creditManager, _router) {
        _getMaskOrRevert(ITreehouseRouter(_router).TASSET());
    }

    /// @notice Deposit a given amount of tokens into TAsset via Treehouse Router
    /// @param token The token to deposit
    /// @param amount The amount of tokens to deposit
    function deposit(address token, uint256 amount) external override creditFacadeOnly returns (bool) {
        _deposit(token, amount);
        return false;
    }

    /// @notice Deposit the entire balance of a token into TAsset via Treehouse Router, except the specified amount
    /// @param token The token to deposit
    /// @param leftoverAmount The amount of token to leave on the account
    function depositDiff(address token, uint256 leftoverAmount) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();

        uint256 amount = IERC20(token).balanceOf(creditAccount);

        if (amount <= leftoverAmount) return false;
        unchecked {
            amount -= leftoverAmount;
        }

        _deposit(token, amount);
        return false;
    }

    /// @dev Internal implementation for `deposit`
    function _deposit(address token, uint256 amount) internal {
        if (!_allowedAssets.contains(token)) revert InvalidAssetException();

        _executeSwapSafeApprove(token, abi.encodeCall(ITreehouseRouter.deposit, (token, amount)));
    }

    // ---- //
    // DATA //
    // ---- //

    function isAssetAllowed(address asset) external view override returns (bool) {
        return _allowedAssets.contains(asset);
    }

    function allowedAssets() public view override returns (address[] memory) {
        return _allowedAssets.values();
    }

    function serialize() external view override returns (bytes memory) {
        return abi.encode(creditManager, targetContract, allowedAssets());
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function setAssetStatusBatch(address[] calldata assets, bool[] calldata allowed)
        external
        override
        configuratorOnly
    {
        uint256 len = assets.length;
        for (uint256 i = 0; i < len; ++i) {
            if (allowed[i]) {
                _getMaskOrRevert(assets[i]);
                _allowedAssets.add(assets[i]);
            } else {
                _allowedAssets.remove(assets[i]);
            }
            emit SetAssetStatus(assets[i], allowed[i]);
        }
    }
}
