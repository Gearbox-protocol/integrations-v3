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
    constructor(address _creditManager, address _wstETH)
        AbstractAdapter(_creditManager, _wstETH) // U:[LDO1W-1]
    {
        stETH = IwstETH(_wstETH).stETH(); // U:[LDO1W-1]
        wstETHTokenMask = _getMaskOrRevert(_wstETH); // U:[LDO1W-1]
        stETHTokenMask = _getMaskOrRevert(stETH); // U:[LDO1W-1]
    }

    // ---- //
    // WRAP //
    // ---- //

    /// @notice Wraps given amount of stETH into wstETH
    /// @param amount Amount of stETH to wrap
    function wrap(uint256 amount)
        external
        override
        creditFacadeOnly // U:[LDO1W-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _wrap(amount, false); // U:[LDO1W-3]
    }

    /// @notice Wraps the entire balance of stETH into wstETH, disables stETH
    function wrapAll()
        external
        override
        creditFacadeOnly // U:[LDO1W-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[LDO1W-4]

        uint256 balance = IERC20(stETH).balanceOf(creditAccount); // U:[LDO1W-4]
        if (balance > 1) {
            unchecked {
                (tokensToEnable, tokensToDisable) = _wrap(balance - 1, true); // U:[LDO1W-4]
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
        _approveToken(stETH, type(uint256).max); // U:[LDO1W-3,4]
        _execute(abi.encodeCall(IwstETH.wrap, (amount))); // U:[LDO1W-3,4]
        _approveToken(stETH, 1); // U:[LDO1W-3,4]
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
        creditFacadeOnly // U:[LDO1W-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _unwrap(amount, false); // U:[LDO1W-5]
    }

    /// @notice Unwraps the entire balance of wstETH to stETH, disables wstETH
    function unwrapAll()
        external
        override
        creditFacadeOnly // U:[LDO1W-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[LDO1W-6]

        uint256 balance = IERC20(targetContract).balanceOf(creditAccount); // U:[LDO1W-6]
        if (balance > 1) {
            unchecked {
                (tokensToEnable, tokensToDisable) = _unwrap(balance - 1, true); // U:[LDO1W-6]
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
        _execute(abi.encodeCall(IwstETH.unwrap, (amount))); // U:[LDO1W-5,6]
        (tokensToEnable, tokensToDisable) = (stETHTokenMask, disableWstETH ? wstETHTokenMask : 0);
    }
}
