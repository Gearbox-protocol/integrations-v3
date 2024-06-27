// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {IwstETH} from "../../integrations/lido/IwstETH.sol";
import {IwstETHV1Adapter} from "../../interfaces/lido/IwstETHV1Adapter.sol";

/// @title wstETH adapter
/// @notice Implements logic for wrapping / unwrapping stETH
contract WstETHV1Adapter is AbstractAdapter, IwstETHV1Adapter {
    uint256 public constant override adapterType = uint256(AdapterType.LIDO_WSTETH_V1);
    uint256 public constant override version = 3_10;

    /// @notice Address of the stETH token
    address public immutable override stETH;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _wstETH wstETH token address
    constructor(address _creditManager, address _wstETH)
        AbstractAdapter(_creditManager, _wstETH) // U:[LDO1W-1]
    {
        stETH = IwstETH(_wstETH).stETH(); // U:[LDO1W-1]
        _getMaskOrRevert(_wstETH); // U:[LDO1W-1]
        _getMaskOrRevert(stETH); // U:[LDO1W-1]
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
        returns (bool)
    {
        _wrap(amount); // U:[LDO1W-3]
        return false;
    }

    /// @notice Wraps the entire balance of stETH into wstETH, except the specified amount
    /// @param leftoverAmount Amount of stETH to keep on the account
    function wrapDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[LDO1W-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[LDO1W-4]

        uint256 balance = IERC20(stETH).balanceOf(creditAccount); // U:[LDO1W-4]
        if (balance > leftoverAmount) {
            unchecked {
                _wrap(balance - leftoverAmount); // U:[LDO1W-4]
            }
        }
        return false;
    }

    /// @dev Internal implementation of `wrap` and `wrapDiff`
    function _wrap(uint256 amount) internal {
        _executeSwapSafeApprove(stETH, abi.encodeCall(IwstETH.wrap, (amount))); // U:[LDO1W-3,4]
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
        returns (bool)
    {
        _unwrap(amount); // U:[LDO1W-5]
        return false;
    }

    /// @notice Unwraps the entire balance of wstETH to stETH, except the specified amount
    /// @param leftoverAmount Amount of wstETH to keep on the account
    function unwrapDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[LDO1W-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[LDO1W-6]

        uint256 balance = IERC20(targetContract).balanceOf(creditAccount); // U:[LDO1W-6]
        if (balance > leftoverAmount) {
            unchecked {
                _unwrap(balance - leftoverAmount); // U:[LDO1W-6]
            }
        }
        return false;
    }

    /// @dev Internal implementation of `unwrap` and `unwrapDiff`
    function _unwrap(uint256 amount) internal {
        _execute(abi.encodeCall(IwstETH.unwrap, (amount))); // U:[LDO1W-5,6]
    }

    /// @notice Returns all adapter parameters serialized into a bytes array,
    ///         as well as adapter type and version, to properly deserialize
    function serialize() external view override returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, stETH);
    }
}
