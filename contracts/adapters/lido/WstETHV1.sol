// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {IwstETH} from "../../integrations/lido/IwstETH.sol";
import {IwstETHV1Adapter} from "../../interfaces/lido/IwstETHV1Adapter.sol";

/// @title wstETH adapter
/// @notice Implements logic for wrapping / unwrapping stETH
contract WstETHV1Adapter is AbstractAdapter, IwstETHV1Adapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.LIDO_WSTETH_V1;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @notice Address of the stETH token
    address public immutable override stETH;

    /// @notice Collateral token mask of stETH in the credit manager
    uint256 public immutable override stETHTokenMask;

    /// @notice Collateral token mask of wstETH in the credit manager
    uint256 public immutable override wstETHTokenMask;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _wstETH wstETH token address
    constructor(address _creditManager, address _wstETH) AbstractAdapter(_creditManager, _wstETH) {
        stETH = IwstETH(_wstETH).stETH(); // F: [AWSTV1-1]
        wstETHTokenMask = _getMaskOrRevert(_wstETH); // F: [AWSTV1-1, AWSTV1-2]
        stETHTokenMask = _getMaskOrRevert(stETH); // F: [AWSTV1-1, AWSTV1-2]
    }

    // ---- //
    // WRAP //
    // ---- //

    /// @notice Wraps given amount of stETH into wstETH
    /// @param amount Amount of stETH to wrap
    function wrap(uint256 amount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _wrap(amount, false); // F: [AWSTV1-5]
    }

    /// @notice Wraps the entire balance of stETH into wstETH, except the specified amount
    /// @param leftoverAmount Amount of stETH to keep on the account
    function wrapDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _wrapDiff(leftoverAmount);
    }

    /// @notice Wraps the entire balance of stETH into wstETH, disables stETH
    function wrapAll() external override creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        (tokensToEnable, tokensToDisable) = _wrapDiff(1);
    }

    /// @dev Internal implementation for `wrapDiff` and `wrapAll`.
    function _wrapDiff(uint256 leftoverAmount) internal returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        address creditAccount = _creditAccount(); // F: [AWSTV1-3]

        uint256 balance = IERC20(stETH).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) = _wrap(balance - leftoverAmount, leftoverAmount <= 1); // F: [AWSTV1-4]
            }
        }
    }

    /// @dev Internal implementation of `wrap` and `wrapAll`
    ///      - stETH is approved before the call
    ///      - wstETH is enabled after the call
    ///      - stETH is only disabled if wrapping the entire balance
    function _wrap(uint256 amount, bool disableStETH)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approveToken(stETH, type(uint256).max);
        _execute(abi.encodeCall(IwstETH.wrap, (amount)));
        _approveToken(stETH, 1);
        (tokensToEnable, tokensToDisable) = (wstETHTokenMask, disableStETH ? stETHTokenMask : 0);
    }

    // ------ //
    // UNWRAP //
    // ------ //

    /// @notice Unwraps given amount of wstETH into stETH
    /// @param amount Amount of wstETH to unwrap
    function unwrap(uint256 amount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _unwrap(amount, false); // F: [AWSTV1-7]
    }

    /// @notice Unwraps the entire balance of wstETH to stETH, except the specified amount
    /// @param leftoverAmount Amount of wstETH to keep on the account
    function unwrapDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _unwrapDiff(leftoverAmount);
    }

    /// @notice Unwraps the entire balance of wstETH to stETH, disables wstETH
    function unwrapAll() external override creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        (tokensToEnable, tokensToDisable) = _unwrapDiff(1);
    }

    /// @dev Internal implementation for `unwrapDiff` and `unwrapAll`.
    function _unwrapDiff(uint256 leftoverAmount) internal returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        address creditAccount = _creditAccount(); // F: [AWSTV1-3]

        uint256 balance = IERC20(targetContract).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) = _unwrap(balance - leftoverAmount, leftoverAmount <= 1); // F: [AWSTV1-6]
            }
        }
    }

    /// @dev Internal implementation of `unwrap` and `unwrapAll`
    ///      - wstETH is not approved before the call
    ///      - stETH is enabled after the call
    ///      - wstETH is only disabled if unwrapping the entire balance
    function _unwrap(uint256 amount, bool disableWstETH)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(abi.encodeCall(IwstETH.unwrap, (amount)));
        (tokensToEnable, tokensToDisable) = (stETHTokenMask, disableWstETH ? wstETHTokenMask : 0);
    }
}
