// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "../../interfaces/IAdapter.sol";

import {IwstETH} from "../../integrations/lido/IwstETH.sol";
import {IwstETHV1Adapter} from "../../interfaces/lido/IwstETHV1Adapter.sol";

/// @title wstETH adapter
/// @notice Implements logic for wrapping / unwrapping stETH
contract WstETHV1Adapter is AbstractAdapter, IwstETHV1Adapter {
    /// @inheritdoc IwstETHV1Adapter
    address public immutable override stETH;

    /// @inheritdoc IwstETHV1Adapter
    uint256 public immutable override stETHTokenMask;

    /// @inheritdoc IwstETHV1Adapter
    uint256 public immutable override wstETHTokenMask;

    AdapterType public constant override _gearboxAdapterType = AdapterType.LIDO_WSTETH_V1;
    uint16 public constant override _gearboxAdapterVersion = 2;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _wstETH wstETH token address
    constructor(address _creditManager, address _wstETH) AbstractAdapter(_creditManager, _wstETH) {
        stETH = IwstETH(_wstETH).stETH(); // F: [AWSTV1-1]
        wstETHTokenMask = _getMaskOrRevert(_wstETH); // F: [AWSTV1-1, AWSTV1-2]
        stETHTokenMask = _getMaskOrRevert(stETH); // F: [AWSTV1-1, AWSTV1-2]
    }

    /// ---- ///
    /// WRAP ///
    /// ---- ///

    /// @inheritdoc IwstETHV1Adapter
    function wrap(uint256 amount) external override creditFacadeOnly {
        _wrap(amount, false); // F: [AWSTV1-5]
    }

    /// @inheritdoc IwstETHV1Adapter
    function wrapAll() external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F: [AWSTV1-3]

        uint256 balance = IERC20(stETH).balanceOf(creditAccount);
        if (balance <= 1) return;

        unchecked {
            _wrap(balance - 1, true); // F: [AWSTV1-4]
        }
    }

    /// @dev Internal implementation of `wrap` and `wrapAll`
    ///      - stETH is approved before the call
    ///      - wstETH is enabled after the call
    ///      - stETH is only disabled if wrapping the entire balance
    function _wrap(uint256 amount, bool disableStETH) internal {
        _approveToken(stETH, type(uint256).max);
        _execute(abi.encodeCall(IwstETH.wrap, (amount)));
        _approveToken(stETH, 1);
        _changeEnabledTokens(wstETHTokenMask, disableStETH ? stETHTokenMask : 0);
    }

    /// ------ ///
    /// UNWRAP ///
    /// ------ ///

    /// @inheritdoc IwstETHV1Adapter
    function unwrap(uint256 amount) external override creditFacadeOnly {
        _unwrap(amount, false); // F: [AWSTV1-7]
    }

    /// @inheritdoc IwstETHV1Adapter
    function unwrapAll() external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F: [AWSTV1-3]

        uint256 balance = IERC20(targetContract).balanceOf(creditAccount);
        if (balance <= 1) return;

        unchecked {
            _unwrap(balance - 1, true); // F: [AWSTV1-6]
        }
    }

    /// @dev Internal implementation of `unwrap` and `unwrapAll`
    ///      - wstETH is not approved before the call
    ///      - stETH is enabled after the call
    ///      - wstETH is only disabled if unwrapping the entire balance
    function _unwrap(uint256 amount, bool disableWstETH) internal {
        _execute(abi.encodeCall(IwstETH.unwrap, (amount)));
        _changeEnabledTokens(stETHTokenMask, disableWstETH ? wstETHTokenMask : 0);
    }
}
