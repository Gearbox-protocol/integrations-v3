// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {IWrappedATokenV2} from "@gearbox-protocol/oracles-v3/contracts/interfaces/aave/IWrappedATokenV2.sol";
import {WERC20ZapperBase} from "./WERC20ZapperBase.sol";

/// @title waToken zapper
/// @notice Allows users to deposit/withdraw an aToken to/from a waToken pool in a single operation
contract WATokenZapper is WERC20ZapperBase {
    /// @dev aToken address
    address internal immutable _aToken;

    /// @notice Constructor
    /// @param pool_ Pool to connect this zapper to
    constructor(address pool_) WERC20ZapperBase(pool_) {
        _aToken = IWrappedATokenV2(wrappedToken).aToken();
        IERC20(_aToken).approve(wrappedToken, type(uint256).max);
    }

    /// @notice aToken address
    function unwrappedToken() public view override returns (address) {
        return _aToken;
    }

    /// @dev Wraps aToken
    function _wrap(uint256 amount) internal override returns (uint256 assets) {
        return IWrappedATokenV2(wrappedToken).deposit(amount);
    }

    /// @dev Unwraps waToken
    function _unwrap(uint256 assets) internal override returns (uint256 amount) {
        return IWrappedATokenV2(wrappedToken).withdraw(assets);
    }

    /// @dev Returns amount of waToken one would receive for wrapping `amount` of aToken
    function _previewWrap(uint256 amount) internal view override returns (uint256 wrappedAmount) {
        return amount * WAD / IWrappedATokenV2(wrappedToken).exchangeRate();
    }

    /// @dev Returns amount of aToken one would receive for unwrapping `amount` of waToken
    function _previewUnwrap(uint256 amount) internal view override returns (uint256 unwrappedAmount) {
        return amount * IWrappedATokenV2(wrappedToken).exchangeRate() / WAD;
    }

    /// @dev Pool has infinite waToken allowance so this step can be skipped
    function _ensurePoolAllowance(uint256) internal override {}
}
