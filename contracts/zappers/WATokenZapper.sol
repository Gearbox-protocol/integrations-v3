// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {WrappedAToken} from "../helpers/aave/AaveV2_WrappedAToken.sol";
import {WERC20ZapperBase} from "./WERC20ZapperBase.sol";

/// @title waToken zapper
/// @notice Allows users to deposit/withdraw an aToken to/from a waToken pool in a single operation
contract WATokenZapper is WERC20ZapperBase {
    /// @dev aToken address
    address internal immutable _aToken;

    /// @notice Constructor
    /// @param pool_ Pool to connect this zapper to
    constructor(address pool_) WERC20ZapperBase(pool_) {
        _aToken = WrappedAToken(wrappedToken).aToken();
        super._resetWrapperAllowance();
    }

    /// @notice aToken address
    function unwrappedToken() public view override returns (address) {
        return _aToken;
    }

    /// @dev Wraps aToken
    function _wrap(uint256 amount) internal override returns (uint256 assets) {
        return WrappedAToken(wrappedToken).deposit(amount);
    }

    /// @dev Unwraps waToken
    function _unwrap(uint256 assets) internal override returns (uint256 amount) {
        return WrappedAToken(wrappedToken).withdraw(assets);
    }

    /// @dev Returns amount of waToken one would receive for wrapping `amount` of aToken
    function _previewWrap(uint256 amount) internal view override returns (uint256 wrappedAmount) {
        return amount * WAD / WrappedAToken(wrappedToken).exchangeRate();
    }

    /// @dev Returns amount of aToken one would receive for unwrapping `amount` of waToken
    function _previewUnwrap(uint256 amount) internal view override returns (uint256 unwrappedAmount) {
        return amount * WrappedAToken(wrappedToken).exchangeRate() / WAD;
    }

    /// @dev Pool has infinite waToken allowance so this step can be skipped
    function _resetPoolAllowance() internal override {}
}
