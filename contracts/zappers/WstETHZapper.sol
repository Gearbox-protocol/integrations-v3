// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IwstETH} from "../integrations/lido/IwstETH.sol";
import {WERC20ZapperBase} from "./WERC20ZapperBase.sol";

/// @title wstETH zapper
/// @notice Allows users to deposit/withdraw stETH to/from a wstETH pool in a single operation
contract WstETHZapper is WERC20ZapperBase {
    /// @dev stETH address
    address internal immutable _stETH;

    /// @notice Constructor
    /// @param pool_ Pool to connect this zapper to
    constructor(address pool_) WERC20ZapperBase(pool_) {
        _stETH = IwstETH(wrappedToken).stETH();
        IERC20(_stETH).approve(wrappedToken, type(uint256).max);
    }

    /// @notice stETH address
    function unwrappedToken() public view override returns (address) {
        return _stETH;
    }

    /// @dev Wraps stETH
    function _wrap(uint256 amount) internal override returns (uint256 assets) {
        return IwstETH(wrappedToken).wrap(amount);
    }

    /// @dev Unwraps wstETH
    function _unwrap(uint256 assets) internal override returns (uint256 amount) {
        return IwstETH(wrappedToken).unwrap(assets);
    }
}
