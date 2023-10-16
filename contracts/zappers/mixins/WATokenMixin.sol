// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {WrappedAToken} from "../../helpers/aave/AaveV2_WrappedAToken.sol";
import {ERC20ZapperBase} from "../ERC20ZapperBase.sol";
import {ZapperBase} from "../ZapperBase.sol";

/// @title waToken mixin
/// @notice Implements tokenIn <-> underlying conversion functions for waToken pool zappers with aToken as input token
abstract contract WATokenMixin is ERC20ZapperBase {
    using SafeERC20 for IERC20;

    /// @dev aToken address
    address internal immutable _aToken;

    /// @notice Constructor
    constructor() {
        _aToken = WrappedAToken(underlying).aToken();
        _resetAllowance(_aToken, underlying);
    }

    /// @inheritdoc ZapperBase
    /// @dev Returns aToken address
    function tokenIn() public view override returns (address) {
        return _aToken;
    }

    /// @inheritdoc ZapperBase
    function _previewTokenInToUnderlying(uint256 tokenInAmount) internal view override returns (uint256 assets) {
        assets = tokenInAmount * WAD / WrappedAToken(underlying).exchangeRate();
    }

    /// @inheritdoc ZapperBase
    function _previewUnderlyingToTokenIn(uint256 assets) internal view override returns (uint256 tokenInAmount) {
        tokenInAmount = assets * WrappedAToken(underlying).exchangeRate() / WAD;
    }

    /// @inheritdoc ZapperBase
    function _tokenInToUnderlying(uint256 tokenInAmount) internal override returns (uint256 assets) {
        IERC20(_aToken).safeTransferFrom(msg.sender, address(this), tokenInAmount);
        assets = WrappedAToken(underlying).deposit(tokenInAmount);
    }

    /// @inheritdoc ZapperBase
    function _underlyingToTokenIn(uint256 assets, address receiver) internal override returns (uint256 tokenInAmount) {
        tokenInAmount = WrappedAToken(underlying).withdraw(assets);
        IERC20(_aToken).safeTransfer(receiver, tokenInAmount);
    }
}
