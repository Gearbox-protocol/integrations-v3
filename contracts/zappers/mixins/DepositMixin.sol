// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IFarmingPool} from "@1inch/farming/contracts/interfaces/IFarmingPool.sol";
import {ZapperBase} from "../ZapperBase.sol";

/// @title Deposit mixin
/// @dev Provides empty shares <-> tokenOut conversion functions implementation for zappers with pool as output token
abstract contract DepositMixin is ZapperBase {
    /// @inheritdoc ZapperBase
    /// @dev Returns pool address
    function tokenOut() public view override returns (address) {
        return pool;
    }

    /// @inheritdoc ZapperBase
    /// @dev Does nothing
    function _previewSharesToTokenOut(uint256 shares) internal view override returns (uint256 tokenOutAmount) {}

    /// @inheritdoc ZapperBase
    /// @dev Does nothing
    function _previewTokenOutToShares(uint256 tokenOutAmount) internal view override returns (uint256 shares) {}

    /// @inheritdoc ZapperBase
    /// @dev Does nothing
    function _sharesToTokenOut(uint256 shares, address receiver) internal override returns (uint256 tokenOutAmount) {}

    /// @inheritdoc ZapperBase
    /// @dev Does nothing
    function _tokenOutToShares(uint256 tokenOutAmount, address owner) internal override returns (uint256 shares) {}
}
